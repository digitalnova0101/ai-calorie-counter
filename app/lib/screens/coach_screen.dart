// AI coach: a chat that knows the user's goal and today's food.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../services/goals.dart';
import '../services/units.dart';
import '../services/health_data.dart';
import '../theme.dart';
import '../widgets/ui.dart';

const coachChips = [
  'Can I eat a samosa today?',
  'Is poha good for weight loss?',
  'What should I eat for dinner?',
  'How am I doing this week?',
  'High-protein veg snacks?',
  'Is it ok to eat rice at night?',
];

String _coachUrl() {
  if (kApiUrl.isEmpty) return '';
  if (kApiUrl.contains('analyze.php')) return kApiUrl.replaceFirst('analyze.php', 'coach.php');
  if (kApiUrl.contains('/api/')) return kApiUrl.replaceFirst(RegExp(r'/api/[^/]*$'), '/api/coach');
  return '$kApiUrl/api/coach';
}

/// Opens the coach as a tall sheet. [question] is sent straight away when given.
Future<void> openCoach(BuildContext context, Profile profile, {String? question}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: CoachSheet(profile: profile, question: question),
      ),
    );

/// The sparkle logo in a green-blue rounded square.
class CoachLogo extends StatelessWidget {
  final double size;
  const CoachLogo({super.key, this.size = 40});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .34),
        gradient: LinearGradient(colors: [p.leaf, p.water], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: p.leaf.withValues(alpha: .45), blurRadius: 14, offset: const Offset(0, 5))],
      ),
      child: Icon(Icons.auto_awesome, color: Colors.white, size: size * .52),
    );
  }
}

class _Msg {
  final String role, text;
  final bool err;
  _Msg(this.role, this.text, [this.err = false]);
  Map<String, dynamic> toJson() => {'r': role, 't': text, 'e': err};
  static _Msg from(Map m) => _Msg('${m['r']}', '${m['t']}', m['e'] == true);
}

class CoachSheet extends StatefulWidget {
  final Profile profile;
  final String? question;
  const CoachSheet({super.key, required this.profile, this.question});
  @override
  State<CoachSheet> createState() => _CoachSheetState();
}

class _CoachSheetState extends State<CoachSheet> {
  final _msgs = <_Msg>[];
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _busy = false;
  List<DayLog> _days = [];
  List<WeightEntry> _weights = [];

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final raw = sp.getString('coach_chat');
      if (raw != null) _msgs.addAll((jsonDecode(raw) as List).map((e) => _Msg.from(e as Map)));
    } catch (_) {}
    try {
      _days = await Db.instance.recentDays(7);
      _weights = await Db.instance.weightsStream().first.timeout(const Duration(seconds: 5));
    } catch (_) {}
    if (!mounted) return;
    setState(() {});
    _toEnd();
    if (widget.question != null) _send(widget.question!);
  }

  Future<void> _save() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final keep = _msgs.length > 40 ? _msgs.sublist(_msgs.length - 40) : _msgs;
      await sp.setString('coach_chat', jsonEncode(keep.map((m) => m.toJson()).toList()));
    } catch (_) {}
  }

  void _toEnd() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      });

  ({double kcal, double protein, Totals t}) _left() {
    final g = widget.profile.goals;
    final today = _days.isNotEmpty ? _days.first : DayLog.empty(dayKey(DateTime.now()));
    final t = today.totals;
    return (kcal: g.kcal - t.kcal, protein: g.protein - t.protein, t: t);
  }

  String _context() {
    final p = widget.profile, g = p.goals, now = DateTime.now();
    final today = _days.isNotEmpty ? _days.first : DayLog.empty(dayKey(now));
    final t = today.totals, l = _left();
    final cur = _weights.isNotEmpty ? _weights.last.kg : p.weightKg;
    final b = bmi(cur, p.heightCm);
    final meals = today.meals
        .map((m) => '${m.type}: ${m.items.map((i) => '${i.name} (${i.tKcal.round()} kcal)').join(', ')}')
        .join(' | ');
    final logged = _days.where((d) => d.meals.isNotEmpty).toList();
    double avg(double Function(DayLog) f) => logged.isEmpty ? 0 : logged.map(f).reduce((a, c) => a + c) / logged.length;
    final h = now.hour;
    return [
      'Time now: ${now.hour}:${now.minute.toString().padLeft(2, '0')} (${h < 12 ? 'morning' : h < 16 ? 'afternoon' : h < 20 ? 'evening' : 'night'})',
      'User: ${p.name.isEmpty ? 'friend' : p.name}, ${p.sex}, ${p.age} yrs, ${Units.height(p.heightCm)}, ${Units.weight(cur)}, prefers ${Units.imperial ? 'lb, ft, oz, miles' : 'kg, cm, ml, km'}, time zone UTC${DateTime.now().timeZoneOffset.isNegative ? '-' : '+'}${DateTime.now().timeZoneOffset.inMinutes.abs() ~/ 60}, BMI ${b.toStringAsFixed(1)} (${bmiBandOf(b).name}, Asian-Indian ranges), activity: ${p.activity}',
      'Goal: ${p.goal == 'lose' ? 'lose weight' : p.goal == 'gain' ? 'gain weight / build muscle' : 'maintain weight'}${p.goal != 'maintain' && p.targetWeightKg > 0 ? ', target ${Units.weight(p.targetWeightKg)}${p.targetDate.isNotEmpty ? ' by ${p.targetDate}' : ''}' : ''}',
      'Daily targets: ${g.kcal} kcal, protein ${g.protein} g, carbs ${g.carbs} g, fat ${g.fat} g, water ${g.waterMl} ml',
      'Eaten today: ${t.kcal.round()} kcal, protein ${t.protein.round()} g, carbs ${t.carbs.round()} g, fat ${t.fat.round()} g',
      'Left today: ${l.kcal.round()} kcal, protein ${l.protein.round()} g',
      'Meals today: ${meals.isEmpty ? 'nothing logged yet' : meals}',
      'Activity today: ${today.steps} steps, ${burnedOf(today, p).total.round()} kcal burned; water ${today.waterMl} ml',
      'Last 7 days: ${logged.length} days logged, average ${avg((d) => d.totals.kcal).round()} kcal and ${avg((d) => d.totals.protein).round()} g protein a day',
      'Allergies: ${labelsOf(allergyChoices, p.allergies).join(', ').isEmpty ? 'none' : labelsOf(allergyChoices, p.allergies).join(', ')}',
      'Health concerns: ${labelsOf(concernChoices, p.concerns).join(', ').isEmpty ? 'none' : labelsOf(concernChoices, p.concerns).join(', ')}',
    ].join('\n');
  }

  Future<void> _send(String q) async {
    q = q.trim();
    if (q.isEmpty || _busy) return;
    _input.clear();
    setState(() {
      _msgs.add(_Msg('user', q));
      _busy = true;
    });
    _toEnd();
    String reply;
    bool err = false;
    final url = _coachUrl();
    if (url.isEmpty) {
      reply = 'The AI coach will start working as soon as the AI server is connected. Until then you can scan with Search or Barcode.';
      err = true;
    } else {
      try {
        final token = await FirebaseAuth.instance.currentUser?.getIdToken();
        final hist = _msgs.length > 12 ? _msgs.sublist(_msgs.length - 12) : _msgs;
        final res = await http
            .post(Uri.parse(url),
                headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${token ?? ''}'},
                body: jsonEncode({
                  'context': _context(),
                  'messages': hist.where((m) => !m.err).map((m) => {'role': m.role, 'text': m.text}).toList(),
                }))
            .timeout(const Duration(seconds: 60));
        final body = jsonDecode(res.body) as Map;
        if (res.statusCode == 200 && '${body['reply'] ?? ''}'.trim().isNotEmpty) {
          reply = '${body['reply']}'.trim();
        } else {
          reply = '${body['error'] ?? 'Something went wrong. Please try again.'}';
          err = true;
        }
      } catch (_) {
        reply = 'Could not reach the AI coach. Check your internet and try again.';
        err = true;
      }
    }
    if (!mounted) return;
    setState(() {
      _msgs.add(_Msg('model', reply, err));
      _busy = false;
    });
    _save();
    _toEnd();
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final l = _left();
    return Container(
      decoration: BoxDecoration(
        color: p.bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: Column(children: [
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
          child: Row(children: [
            const CoachLogo(size: 38),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('AI coach', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                Muted("Knows your goal and today's food", size: 12),
              ]),
            ),
            IconButton(
              tooltip: 'Clear chat',
              onPressed: () {
                setState(() => _msgs.clear());
                _save();
              },
              icon: const Icon(Icons.delete_outline),
            ),
            IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
          ]),
        ),
        Divider(color: p.line, height: 1),
        Expanded(
          child: ListView(controller: _scroll, padding: const EdgeInsets.all(16), children: [
            Center(
              child: Column(children: [
                const SizedBox(height: 6),
                const CoachLogo(size: 58),
                const SizedBox(height: 10),
                H2("Hi ${widget.profile.name.isEmpty ? 'there' : widget.profile.name}! I'm your AI coach"),
                const SizedBox(height: 4),
                const Muted('I can see your goal and what you ate today. Ask me about any food, in English or Hindi.',
                    align: TextAlign.center),
                const SizedBox(height: 10),
                Wrap(spacing: 8, children: [
                  _ctx(context, '🔥 ${fmtInt(l.kcal < 0 ? 0 : l.kcal)} kcal left'),
                  _ctx(context, '💪 ${(l.protein < 0 ? 0 : l.protein).round()} g protein left'),
                ]),
                const SizedBox(height: 12),
              ]),
            ),
            for (final m in _msgs) _Bubble(m),
            if (_busy) const _Bubble(null),
          ]),
        ),
        // quick questions
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
            for (final c in coachChips)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(c, style: const TextStyle(fontWeight: FontWeight.w700)),
                  onPressed: _busy ? null : () => _send(c),
                  backgroundColor: Color.alphaBlend(p.leaf.withValues(alpha: .08), p.surface),
                  side: BorderSide(color: p.leaf.withValues(alpha: .35)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
                ),
              ),
          ]),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + MediaQuery.of(context).viewInsets.bottom + MediaQuery.paddingOf(context).bottom),
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: InputDecoration(
                  hintText: 'Ask about any food…',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.line, width: 1.5)),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: p.leaf, width: 1.5)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: p.leaf, foregroundColor: Colors.white),
                onPressed: _busy ? null : () => _send(_input.text),
                icon: const Icon(Icons.arrow_upward),
              ),
            ),
          ]),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Muted('AI can make mistakes. Not medical advice.', size: 11),
        ),
      ]),
    );
  }

  Widget _ctx(BuildContext context, String t) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: p.surface, borderRadius: BorderRadius.circular(99), border: Border.all(color: p.line)),
      child: Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
    );
  }
}

/// One chat bubble. null = typing dots.
class _Bubble extends StatelessWidget {
  final _Msg? m;
  const _Bubble(this.m);

  /// Very small markdown: **bold** and "- " bullet lines.
  List<InlineSpan> _spans(String line, TextStyle base) {
    final out = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var i = 0;
    for (final mm in re.allMatches(line)) {
      if (mm.start > i) out.add(TextSpan(text: line.substring(i, mm.start)));
      out.add(TextSpan(text: mm.group(1), style: const TextStyle(fontWeight: FontWeight.w800)));
      i = mm.end;
    }
    if (i < line.length) out.add(TextSpan(text: line.substring(i)));
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final user = m?.role == 'user';
    final base = TextStyle(fontSize: 15, height: 1.45, color: user ? p.surface : p.ink);
    Widget content;
    if (m == null) {
      content = const SizedBox(width: 40, height: 20, child: Center(child: LinearProgressIndicator(minHeight: 3)));
    } else if (user) {
      content = Text(m!.text, style: base);
    } else {
      final lines = m!.text.split(RegExp(r'\n+')).where((l) => l.trim().isNotEmpty).toList();
      content = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final l in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RegExp(r'^\s*([-*•]|\d+\.)\s+').hasMatch(l)
                ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('•  ', style: base),
                    Expanded(
                        child: Text.rich(
                            TextSpan(children: _spans(l.replaceFirst(RegExp(r'^\s*([-*•]|\d+\.)\s+'), ''), base)),
                            style: base)),
                  ])
                : Text.rich(TextSpan(children: _spans(l.trim(), base)), style: base),
          ),
      ]);
    }
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * .8),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 9),
        decoration: BoxDecoration(
          color: user ? p.ink : p.surface,
          border: user ? null : Border.all(color: m?.err == true ? p.chili.withValues(alpha: .4) : p.line),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(user ? 20 : 6),
            bottomRight: Radius.circular(user ? 6 : 20),
          ),
        ),
        child: content,
      ),
    );
  }
}

/// Floating coach button (bottom right) with a small pop-up hint on Today.
class CoachFab extends StatefulWidget {
  final Profile profile;
  final bool showTip;
  const CoachFab({super.key, required this.profile, required this.showTip});
  @override
  State<CoachFab> createState() => _CoachFabState();
}

class _CoachFabState extends State<CoachFab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat();
  bool _tipOff = false, _tipIn = false;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _tipIn = true);
    });
    _tick();
  }

  void _tick() => Future.delayed(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        setState(() => _i = (_i + 1) % coachChips.length);
        _tick();
      });

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final tip = widget.showTip && !_tipOff;
    return Row(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end, children: [
      AnimatedScale(
        scale: tip && _tipIn ? 1 : 0,
        alignment: Alignment.bottomRight,
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutBack,
        child: GestureDetector(
          onTap: () => openCoach(context, widget.profile),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 220),
            margin: const EdgeInsets.only(right: 10, bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: p.surface,
              border: Border.all(color: p.line),
              borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(18), topRight: Radius.circular(18), bottomLeft: Radius.circular(18), bottomRight: Radius.circular(4)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Flexible(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Ask AI coach ✨', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text('"${coachChips[_i]}"',
                        key: ValueKey(_i), maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.5, color: p.muted)),
                  ),
                ]),
              ),
              InkWell(
                onTap: () => setState(() => _tipOff = true),
                child: Padding(padding: const EdgeInsets.all(2), child: Icon(Icons.close, size: 16, color: p.muted)),
              ),
            ]),
          ),
        ),
      ),
      GestureDetector(
        onTap: () => openCoach(context, widget.profile),
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final t = _pulse.value;
            return Stack(alignment: Alignment.center, clipBehavior: Clip.none, children: [
              if (t < .7)
                Container(
                  width: 58 + 26 * (t / .7),
                  height: 58 + 26 * (t / .7),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20 + 8 * t),
                    border: Border.all(color: p.leaf.withValues(alpha: .6 * (1 - t / .7)), width: 2),
                  ),
                ),
              child!,
            ]);
          },
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22), border: Border.all(color: p.bg, width: 4)),
            child: const CoachLogo(size: 56),
          ),
        ),
      ),
    ]);
  }
}

/// Compact "✨ AI coach" button for the top right of a screen.
class CoachTopButton extends StatelessWidget {
  final Profile profile;
  const CoachTopButton({super.key, required this.profile});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Semantics(
      button: true,
      label: 'Ask your AI coach',
      child: Pressable(
        onTap: () => openCoach(context, profile),
        child: Container(
          padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: p.leaf.withValues(alpha: .45), width: 1.5),
            boxShadow: [BoxShadow(color: p.leaf.withValues(alpha: .18), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const CoachLogo(size: 30),
            const SizedBox(width: 8),
            Text('AI coach', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: p.ink)),
          ]),
        ),
      ),
    );
  }
}
