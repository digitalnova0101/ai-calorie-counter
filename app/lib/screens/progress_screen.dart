import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/ui.dart';
import 'report_screen.dart';

class ProgressScreen extends StatefulWidget {
  final Profile profile;
  const ProgressScreen({super.key, required this.profile});
  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late final Stream<List<WeightEntry>> _weights = Db.instance.weightsStream();
  List<DayLog>? _days;

  static const _wd = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Db.instance.recentDays(30);
      if (mounted) setState(() => _days = d);
    } catch (_) {
      if (mounted) setState(() => _days = []);
    }
  }

  Future<void> _logWeight(double current) async {
    final ctrl = TextEditingController(text: current.toStringAsFixed(1));
    final kg = await showAppSheet<double>(context, (ctx) {
      void bump(double d) {
        final v = (double.tryParse(ctrl.text.replaceAll(',', '.')) ?? current) + d;
        ctrl.text = v.toStringAsFixed(1);
      }

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const H2("Today's weight"),
          const SizedBox(height: 12),
          NumberStepper(
            controller: ctrl,
            decimal: true,
            suffix: 'kg',
            onChanged: (_) {},
            onMinus: () => bump(-0.1),
            onPlus: () => bump(0.1),
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text.trim().replaceAll(',', '.'))),
            child: const Text('Save weight'),
          ),
        ]),
      );
    });
    ctrl.dispose();
    if (kg == null) return;
    if (kg < 30 || kg > 250) {
      if (mounted) toast(context, 'Enter a weight between 30 and 250 kg');
      return;
    }
    await Db.instance.logWeight(dayKey(DateTime.now()), kg);
    if (mounted) toast(context, 'Weight saved');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final prof = widget.profile, g = prof.goals;
    final days = _days;
    final week = days == null ? <DayLog>[] : days.take(7).toList().reversed.toList();
    final labels = week.map((d) => _wd[parseDay(d.date).weekday - 1]).toList();
    final todayIdx = week.length - 1;
    final ws = days == null ? null : weekScore(days, prof);
    final (wName, wCol) = gradeOf(ws?.score ?? 0);

    double avg(Iterable<double> v) {
      final l = v.where((x) => x > 0).toList();
      return l.isEmpty ? 0.0 : l.reduce((a, b) => a + b) / l.length;
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 130), children: [
        Text('Progress', style: display(context, 22, weight: FontWeight.w700)),
        const SizedBox(height: 12),

        // weekly report entry
        Panel(
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ReportScreen(profile: prof, date: DateTime.now(), weekly: true))),
          child: Row(children: [
            Ring(
              value: (ws?.hasData ?? false) ? ws!.score / 100 : 0.0,
              color: wCol(p),
              size: 58,
              stroke: 6,
              child: Text('${(ws?.hasData ?? false) ? ws!.score : 0}',
                  style: display(context, 15, weight: FontWeight.w800)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const H2('Weekly report card'),
                Muted((ws?.hasData ?? false)
                    ? '$wName, ${ws!.loggedDays} of 7 days logged'
                    : 'Log meals this week to get a score'),
              ]),
            ),
            Icon(Icons.chevron_right, color: p.muted),
          ]),
        ),
        const SizedBox(height: 12),

        // weight
        StreamBuilder<List<WeightEntry>>(
          stream: _weights,
          builder: (context, snap) {
            final w = snap.data ?? [];
            final last = w.isEmpty ? prof.weightKg : w.last.kg;
            final first = w.isEmpty ? last : w.first.kg;
            final ch = last - first;
            final good = prof.goal == 'gain' ? ch >= 0 : ch <= 0;
            return Column(children: [
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const H2('Weight'),
                        Muted(prof.goal != 'maintain' && prof.targetWeightKg > 0
                            ? 'Goal ${prof.targetWeightKg.toStringAsFixed(1)} kg, ${(last - prof.targetWeightKg).abs().toStringAsFixed(1)} kg to go'
                            : 'Keep it steady'),
                      ]),
                    ),
                    OutlinedButton(onPressed: () => _logWeight(last), child: const Text('Log weight')),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Muted('Now', size: 12),
                        CountUp(last, style: display(context, 22), format: (v) => '${v.toStringAsFixed(1)} kg'),
                      ]),
                    ),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        const Muted('Change', size: 12),
                        Text(w.length > 1 ? '${ch > 0 ? '+' : ''}${ch.toStringAsFixed(1)} kg' : '–',
                            style: display(context, 22, color: w.length > 1 ? (good ? p.leaf : p.chili) : null)),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (w.length < 2)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: Muted('Log your weight on 2 or more days to see your trend line.')),
                    )
                  else
                    WeightChart(entries: w, target: prof.goal != 'maintain' ? prof.targetWeightKg : null),
                ]),
              ),
              const SizedBox(height: 12),
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const H2('Body mass index'),
                  const SizedBox(height: 8),
                  BmiGauge(weightKg: last, heightCm: prof.heightCm),
                ]),
              ),
            ]);
          },
        ),
        const SizedBox(height: 12),

        if (days == null)
          const Panel(child: Column(children: [Shimmer(height: 160, radius: 16)]))
        else ...[
          // food chart
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H2('Food, last 7 days'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _stat(context, 'Avg calories', '${avg(week.map((d) => d.totals.kcal)).round()}')),
                Expanded(child: _stat(context, 'Avg protein', '${avg(week.map((d) => d.totals.protein)).round()} g')),
              ]),
              const SizedBox(height: 12),
              BarChart(
                labels: labels,
                values: week.map((d) => d.totals.kcal).toList(),
                goal: g.kcal.toDouble(),
                under: p.saffron,
                over: p.chili,
                highlight: todayIdx,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // steps chart
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H2('Steps, last 7 days'),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: _stat(context, 'Avg steps', fmtInt(avg(week.map((d) => d.steps.toDouble()))))),
                Expanded(
                    child: _stat(context, 'Avg burned',
                        '${avg(week.map((d) => burnedOf(d, prof).total)).round()} kcal')),
              ]),
              const SizedBox(height: 12),
              BarChart(
                labels: labels,
                values: week.map((d) => d.steps.toDouble()).toList(),
                goal: prof.stepGoal.toDouble(),
                under: p.water,
                over: p.leaf,
                highlight: todayIdx,
              ),
            ]),
          ),
          const SizedBox(height: 12),
          // history
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const H2('History'),
              const SizedBox(height: 6),
              if (days.every((d) => d.meals.isEmpty)) const Muted('Days you log food will show up here.'),
              ...days.where((d) => d.meals.isNotEmpty).map((d) {
                final t = d.totals, over = t.kcal > g.kcal, dt = parseDay(d.date);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  child: Row(children: [
                    SizedBox(
                      width: 92,
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('${_wd[dt.weekday - 1]} ${dt.day}/${dt.month}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        Muted('P ${t.protein.round()}g', size: 12),
                      ]),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: LinearProgressIndicator(
                          value: (t.kcal / g.kcal).clamp(0.0, 1.0),
                          minHeight: 8,
                          color: over ? p.chili : p.saffron,
                          backgroundColor: p.steel,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 52,
                      child: Text('${t.kcal.round()}',
                          textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ]),
                );
              }),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _stat(BuildContext context, String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Muted(label, size: 12),
        Text(value, style: display(context, 20)),
      ]);
}
