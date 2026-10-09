import 'dart:async';

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/ui.dart';

String fmtHms(Duration d) {
  final s = d.inSeconds < 0 ? 0 : d.inSeconds;
  String z(int n) => n.toString().padLeft(2, '0');
  return '${z(s ~/ 3600)}:${z(s % 3600 ~/ 60)}:${z(s % 60)}';
}

String fmtClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

/// Starts or ends a fast. Returns the message to show.
Future<String> toggleFast(FastState f) async {
  if (f.start == null) {
    await Db.instance.setFast(FastState(plan: f.plan, start: DateTime.now().millisecondsSinceEpoch, history: f.history));
    return 'Fast started. Goal: ${f.plan} hours';
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final el = Duration(milliseconds: now - f.start!);
  await Db.instance.setFast(FastState(
      plan: f.plan, start: null, history: [FastRecord(f.start!, now, f.plan), ...f.history]));
  return el.inHours >= f.plan
      ? 'Fast complete: ${fmtHms(el).substring(0, 5)} hours 🎉'
      : 'Fast ended at ${fmtHms(el).substring(0, 5)}';
}

class FastingScreen extends StatefulWidget {
  final FastState fast;
  const FastingScreen({super.key, required this.fast});
  @override
  State<FastingScreen> createState() => _FastingScreenState();
}

class _FastingScreenState extends State<FastingScreen> {
  late FastState _f = widget.fast;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    final msg = await toggleFast(_f);
    if (!mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _f = _f.start == null
          ? FastState(plan: _f.plan, start: now, history: _f.history)
          : FastState(plan: _f.plan, start: null, history: [FastRecord(_f.start!, now, _f.plan), ..._f.history]);
    });
    toast(context, msg);
  }

  Future<void> _setPlan(int h) async {
    setState(() => _f = FastState(plan: h, start: _f.start, history: _f.history));
    await Db.instance.setFast(_f);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final goal = Duration(hours: _f.plan);
    final on = _f.start != null;
    final el = on ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(_f.start!)) : Duration.zero;
    final frac = on ? el.inSeconds / goal.inSeconds : 0.0;
    final done = on && el >= goal;
    final start = on ? DateTime.fromMillisecondsSinceEpoch(_f.start!) : DateTime.now();
    const plans = [(14, 'Gentle'), (16, 'Popular'), (18, 'Advanced'), (20, 'Warrior')];

    return Scaffold(
      appBar: AppBar(title: const Text('Fasting timer')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 32), children: [
        SizedBox(
          height: 58,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: plans.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final (h, n) = plans[i];
              final sel = _f.plan == h;
              return Pressable(
                onTap: () => _setPlan(h),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: sel ? p.saffron.withValues(alpha: 0.12) : p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? p.saffron : p.line, width: 1.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('$h:${24 - h}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    Muted(n, size: 11),
                  ]),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Ring(
            value: frac,
            color: done ? p.leaf : p.saffron,
            size: 270,
            stroke: 16,
            ticks: 24,
            duration: const Duration(milliseconds: 700),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Muted(!on ? 'Not fasting' : (done ? 'Goal reached' : 'Fasting'), size: 14),
              const SizedBox(height: 4),
              Text(fmtHms(el), style: display(context, 34)),
              const SizedBox(height: 4),
              Muted(on ? (done ? '${_f.plan} h goal done' : '${fmtHms(goal - el)} left of ${_f.plan} h') : 'Goal: ${_f.plan} hours'),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: Panel(radius: 16, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Muted('Started', size: 12), Text(on ? fmtClock(start) : '–', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))]))),
          const SizedBox(width: 10),
          Expanded(child: Panel(radius: 16, padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Muted('Goal ends', size: 12), Text(fmtClock(start.add(goal)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17))]))),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: on ? null : FilledButton.styleFrom(backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
            onPressed: _toggle,
            child: Text(on ? 'End fast' : 'Start fasting'),
          ),
        ),
        const SizedBox(height: 14),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2('Recent fasts'),
            const SizedBox(height: 6),
            if (_f.history.isEmpty) const Muted('Your completed fasts show up here.'),
            ..._f.history.take(6).map((h) {
              final d = Duration(milliseconds: h.end - h.start);
              final ok = d.inHours >= h.plan;
              final day = DateTime.fromMillisecondsSinceEpoch(h.start);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(children: [
                  SizedBox(
                    width: 96,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${day.day}/${day.month}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      Muted('${h.plan}:${24 - h.plan}', size: 12),
                    ]),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: LinearProgressIndicator(
                        value: (d.inSeconds / (h.plan * 3600)).clamp(0.0, 1.0),
                        minHeight: 8,
                        color: ok ? p.leaf : p.saffron,
                        backgroundColor: p.steel,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(fmtHms(d).substring(0, 5), style: const TextStyle(fontWeight: FontWeight.w800)),
                ]),
              );
            }),
          ]),
        ),
        const SizedBox(height: 10),
        const Muted("Fasting isn't right for everyone. Check with a doctor if you're pregnant, diabetic or on medication.",
            size: 12, align: TextAlign.center),
      ]),
    );
  }
}
