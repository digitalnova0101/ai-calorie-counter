import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/ui.dart';

/// Daily / weekly report card with a shareable image.
class ReportScreen extends StatefulWidget {
  final Profile profile;
  final DateTime date;
  final bool weekly;
  const ReportScreen({super.key, required this.profile, required this.date, this.weekly = false});
  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late bool _weekly = widget.weekly;
  List<DayLog>? _days;
  DayLog? _day;
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = await Db.instance.recentDays(7);
    final key = dayKey(widget.date);
    final d = days.where((x) => x.date == key).toList();
    DayLog day;
    if (d.isNotEmpty) {
      day = d.first;
    } else {
      day = await Db.instance.dayStream(key).first;
    }
    if (mounted) setState(() {
      _days = days;
      _day = day;
    });
  }

  String get _when {
    if (!_weekly) {
      final k = dayKey(widget.date);
      return k == dayKey(DateTime.now()) ? 'Today' : '${widget.date.day}/${widget.date.month}/${widget.date.year}';
    }
    final from = DateTime.now().subtract(const Duration(days: 6));
    return '${from.day}/${from.month} to ${DateTime.now().day}/${DateTime.now().month}';
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final ready = _days != null && _day != null;
    final Score s = !ready
        ? Score(0, [], [], false)
        : (_weekly ? weekScore(_days!, widget.profile) : dayScore(_day!, widget.profile));
    final has = s.hasData;
    final sc = has ? s.score : 0;
    final (gName, gCol) = gradeOf(sc);

    return Scaffold(
      appBar: AppBar(title: const Text('Report card')),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, bottomGap(context)), children: [
        _Segment(weekly: _weekly, onChanged: (w) => setState(() => _weekly = w)),
        const SizedBox(height: 12),
        if (!ready)
          const Panel(child: Column(children: [Shimmer(width: 200, height: 200, radius: 100), SizedBox(height: 16), Shimmer(width: 120)]))
        else if (!has)
          Panel(
            child: Column(children: [
              const SizedBox(height: 12),
              const H2('No data yet'),
              const SizedBox(height: 6),
              Muted('Log meals ${_weekly ? 'this week' : 'today'} and your report card appears here.', align: TextAlign.center),
              const SizedBox(height: 12),
            ]),
          )
        else ...[
          Panel(
            child: Column(children: [
              Muted(_when),
              const SizedBox(height: 8),
              Ring(
                key: ValueKey('r$_weekly'),
                value: sc / 100,
                color: gCol(p),
                size: 210,
                stroke: 16,
                duration: const Duration(milliseconds: 1400),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CountUp(sc.toDouble(), key: ValueKey('c$_weekly'), style: display(context, 54)),
                  const Muted('out of 100'),
                ]),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                decoration: BoxDecoration(color: gCol(p).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                child: Text(gName, style: TextStyle(color: gCol(p), fontWeight: FontWeight.w800)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(
              children: s.parts
                  .map((pt) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Expanded(child: Text(pt.name, style: const TextStyle(fontWeight: FontWeight.w800))),
                            Muted(pt.note),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: TweenAnimationBuilder<double>(
                              key: ValueKey('${pt.name}$_weekly'),
                              tween: Tween(begin: 0, end: (pt.pts / pt.max).clamp(0.0, 1.0)),
                              duration: const Duration(milliseconds: 1100),
                              curve: Curves.easeOutCubic,
                              builder: (_, v, __) => LinearProgressIndicator(
                                  value: v, minHeight: 9, color: pt.color(p), backgroundColor: p.steel),
                            ),
                          ),
                        ]),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 12),
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              H2(_weekly ? 'Your week' : 'What to do next'),
              const SizedBox(height: 10),
              ...s.tips.map((t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(color: t.$1(p), shape: BoxShape.circle)),
                      const SizedBox(width: 10),
                      Expanded(child: Text(t.$2)),
                    ]),
                  )),
            ]),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 54,
            child: FilledButton.icon(
              onPressed: _sharing ? null : () => _share(s, sc, gName, gCol(Palette.light)),
              icon: const Icon(Icons.ios_share),
              label: const Text('Share report'),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _share(Score s, int sc, String grade, Color gradeColor) async {
    setState(() => _sharing = true);
    try {
      final bytes = await _renderImage(s, sc, grade, gradeColor);
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'image/png', name: 'calorie-report.png')],
        text: 'My calorie score: $sc/100 ($grade)',
      ));
    } catch (e) {
      if (mounted) toast(context, 'Could not share: $e');
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  /// Draws a 1080x1350 report image (Instagram portrait size).
  Future<Uint8List> _renderImage(Score s, int sc, String grade, Color gradeColor) async {
    const w = 1080.0, h = 1350.0;
    final p = Palette.light;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, const Rect.fromLTWH(0, 0, w, h));
    c.drawRect(
        const Rect.fromLTWH(0, 0, w, h),
        Paint()
          ..shader = ui.Gradient.linear(const Offset(0, 0), const Offset(0, h),
              [p.heroA, const Color(0xFFF7FBF9), Colors.white], [0, .55, 1]));

    void text(String t, Offset at, TextStyle st, {TextAlign align = TextAlign.left, double maxW = 900}) {
      final tp = TextPainter(text: TextSpan(text: t, style: st), textDirection: TextDirection.ltr, textAlign: align)
        ..layout(maxWidth: maxW);
      final dx = align == TextAlign.center ? tp.width / 2 : (align == TextAlign.right ? tp.width : 0.0);
      tp.paint(c, at - Offset(dx, tp.height / 2));
    }

    final disp = GoogleFonts.unbounded(fontWeight: FontWeight.w800, color: p.ink);
    final body = GoogleFonts.manrope(fontWeight: FontWeight.w700, color: p.muted);

    // header logo + name
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round;
    c.drawCircle(const Offset(110, 110), 36, ring..color = p.plateTrack);
    c.drawArc(Rect.fromCircle(center: const Offset(110, 110), radius: 36), -math.pi / 2, math.pi * 1.5, false,
        ring..color = p.saffron);
    text('CalDay', const Offset(166, 112), disp.copyWith(fontSize: 36));
    text(_weekly ? 'Weekly report' : 'Daily report', const Offset(w - 80, 96), body.copyWith(fontSize: 32),
        align: TextAlign.right);
    text(_when, const Offset(w - 80, 140), body.copyWith(fontSize: 28, fontWeight: FontWeight.w600),
        align: TextAlign.right);

    // score ring
    const center = Offset(w / 2, 470);
    final big = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 46
      ..strokeCap = StrokeCap.round;
    c.drawCircle(center, 230, big..color = p.plateTrack);
    c.drawArc(Rect.fromCircle(center: center, radius: 230), -math.pi / 2, math.pi * 2 * sc / 100, false,
        big..color = gradeColor);
    text('$sc', center - const Offset(0, 14), disp.copyWith(fontSize: 170), align: TextAlign.center);
    text('out of 100', center + const Offset(0, 95), body.copyWith(fontSize: 36), align: TextAlign.center);
    text(grade, const Offset(w / 2, 470 + 230 + 90), disp.copyWith(fontSize: 54, color: gradeColor),
        align: TextAlign.center);

    // parts
    var y = 880.0;
    for (final pt in s.parts.take(5)) {
      text(pt.name, Offset(90, y), body.copyWith(fontSize: 32, color: p.ink, fontWeight: FontWeight.w800));
      text(pt.note, Offset(w - 90, y), body.copyWith(fontSize: 28, fontWeight: FontWeight.w600), align: TextAlign.right);
      final barR = RRect.fromRectAndRadius(Rect.fromLTWH(90, y + 30, w - 180, 18), const Radius.circular(9));
      c.drawRRect(barR, Paint()..color = p.plateTrack);
      final fw = math.max(18.0, (w - 180) * (pt.pts / pt.max).clamp(0.0, 1.0));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(90, y + 30, fw, 18), const Radius.circular(9)),
          Paint()..color = pt.color(p));
      y += _weekly ? 120 : 80;
    }
    text('Tracked with CalDay', const Offset(w / 2, h - 60), body.copyWith(fontSize: 28),
        align: TextAlign.center);

    final image = await rec.endRecording().toImage(w.toInt(), h.toInt());
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }
}

class _Segment extends StatelessWidget {
  final bool weekly;
  final ValueChanged<bool> onChanged;
  const _Segment({required this.weekly, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget b(String t, bool v) => Expanded(
          child: GestureDetector(
            onTap: () => onChanged(v),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(vertical: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: weekly == v ? p.forest : Colors.transparent, borderRadius: BorderRadius.circular(11)),
              child: Text(t,
                  style: TextStyle(fontWeight: FontWeight.w800, color: weekly == v ? p.forestInk : p.muted)),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: p.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: p.line)),
      child: Row(children: [b('Today', false), b('This week', true)]),
    );
  }
}
