import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/units.dart';
import '../services/device.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/ui.dart';
import '../widgets/premium.dart';
import 'coach_screen.dart';
import 'onboarding_screen.dart';
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
  int _range = 30;
  bool _histAll = false;
  int _stepDays = 30;

  static const _wd = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      // pull past days' steps from Health Connect first (quick when already done today)
      await StepsService.instance
          .syncRecent((d, n) => Db.instance.setSteps(dayKey(d), n))
          .timeout(const Duration(seconds: 12), onTimeout: () => 0);
    } catch (_) {}
    try {
      final d = await Db.instance.recentDays(30);
      if (mounted) setState(() => _days = d);
    } catch (_) {
      if (mounted) setState(() => _days = []);
    }
  }

  Future<void> _logWeight(double current) async {
    final ctrl = TextEditingController(text: Units.toW(current).toStringAsFixed(1));
    final typed = await showAppSheet<double>(context, (ctx) {
      void bump(double d) {
        final v = (double.tryParse(ctrl.text.replaceAll(',', '.')) ?? Units.toW(current)) + d;
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
            suffix: Units.w,
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
    if (typed == null) return;
    final kg = Units.fromW(typed);
    if (kg < 30 || kg > 250) {
      if (mounted) toast(context, 'Enter a weight between ${Units.weight(30, 0)} and ${Units.weight(250, 0)}');
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
    void openReport() => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => ReportScreen(profile: prof, date: DateTime.now(), weekly: true)));
    void fixGoal() => Navigator.of(context).push(MaterialPageRoute(builder: (_) => OnboardingScreen(initial: prof)));

    return RefreshIndicator(
      onRefresh: _load,
      child: StreamBuilder<List<WeightEntry>>(
        stream: _weights,
        builder: (context, snap) {
          final all = snap.data ?? [];
          final last = all.isEmpty ? prof.weightKg : all.last.kg;
          // weights inside the chosen range (keep one point before it as the starting line)
          var ranged = all;
          if (_range > 0 && all.isNotEmpty) {
            final cut = dayKey(DateTime.now().subtract(Duration(days: _range)));
            final inR = all.where((w) => w.date.compareTo(cut) >= 0).toList();
            final before = all.where((w) => w.date.compareTo(cut) < 0).toList();
            ranged = inR.isEmpty ? [all.last] : [if (before.isNotEmpty) before.last, ...inR];
          }
          final first = ranged.isEmpty ? last : ranged.first.kg, ch = last - first;
          final good = prof.goal == 'gain' ? ch >= 0 : ch <= 0;

          final logged = week.where((d) => d.meals.isNotEmpty).toList();
          final avgT = Totals();
          if (logged.isNotEmpty) {
            for (final d in logged) {
              final t = d.totals;
              avgT.kcal += t.kcal / logged.length;
              avgT.protein += t.protein / logged.length;
              avgT.carbs += t.carbs / logged.length;
              avgT.fat += t.fat / logged.length;
            }
          }
          final onT = logged.where((d) => (d.totals.kcal - g.kcal).abs() <= g.kcal * .1).length;
          // steps: last 30 (or 7) days, oldest first
          const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
          final sDays = days == null ? <DayLog>[] : days.take(_stepDays).toList().reversed.toList();
          final steps = sDays.map((d) => d.steps).toList();
          final sLabels = [
            for (var i = 0; i < sDays.length; i++)
              _stepDays <= 7
                  ? _wd[parseDay(sDays[i].date).weekday - 1]
                  : (parseDay(sDays[i].date).day == 1
                      ? '1 ${mo[parseDay(sDays[i].date).month - 1]}'
                      : '${parseDay(sDays[i].date).day}')
          ];
          final bestI = steps.isEmpty ? -1 : steps.indexOf(steps.reduce(math.max));
          String dayName(int i) {
            final d = parseDay(sDays[i].date);
            return _stepDays <= 7 ? _wd[d.weekday - 1] : '${d.day} ${mo[d.month - 1]}';
          }
          double avg(Iterable<double> v) {
            final l = v.where((x) => x > 0).toList();
            return l.isEmpty ? 0.0 : l.reduce((a, b) => a + b) / l.length;
          }

          final hist = days == null ? <DayLog>[] : days.where((d) => d.meals.isNotEmpty).toList();
          return ListView(padding: EdgeInsets.fromLTRB(16, 12, 16, bottomGap(context, 30)), children: [
            Row(children: [
              Expanded(child: Text('Progress', style: display(context, 22, weight: FontWeight.w700))),
              CoachTopButton(profile: prof),
            ]),
            const SizedBox(height: 12),
            if (prof.goal != 'maintain' && prof.targetWeightKg > 0) ...[
              GoalProgressCard(profile: prof, weights: all, onFixGoal: fixGoal),
              const SizedBox(height: 12),
              WeightPlanCard(profile: prof, weights: all, today: days?.first),
              const SizedBox(height: 12),
            ],
            if (days == null)
              const Panel(child: Shimmer(height: 200, radius: 16))
            else
              WeekHero(days: days, profile: prof, weights: all, onTap: openReport),
            const SizedBox(height: 12),

            // weight
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                SectionHead('⚖️', 'Weight', p.saffron,
                    sub: prof.goal != 'maintain' && prof.targetWeightKg > 0
                        ? 'Goal ${kg(prof.targetWeightKg)} · ${kg((last - prof.targetWeightKg).abs())} to go'
                        : 'Keep it steady',
                    trailing: OutlinedButton(
                      onPressed: () => _logWeight(last),
                      style: OutlinedButton.styleFrom(minimumSize: const Size(0, 40)),
                      child: const Text('+ Log'),
                    )),
                const SizedBox(height: 14),
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Muted('Now', size: 12),
                    CountUp(last, style: display(context, 28, weight: FontWeight.w700), format: (v) => kg(v)),
                  ]),
                  const SizedBox(width: 12),
                  if (ranged.length > 1)
                    Pill('${ch > 0 ? '▲ +' : (ch < 0 ? '▼ ' : '')}${kg(ch)}', ch == 0 ? p.muted : (good ? p.leaf : p.chili)),
                ]),
                const SizedBox(height: 12),
                RangeTabs(value: _range, onChanged: (v) => setState(() => _range = v)),
                const SizedBox(height: 12),
                if (ranged.length < 2)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Muted('Log your weight on 2 or more days to see your trend line.')),
                  )
                else
                  WeightChart(
                      key: ValueKey('w$_range${ranged.length}'),
                      entries: ranged,
                      target: prof.goal != 'maintain' ? prof.targetWeightKg : null),
              ]),
            ),
            const SizedBox(height: 12),
            Panel(child: BmiCard(weightKg: last, heightCm: prof.heightCm)),
            const SizedBox(height: 12),

            if (days != null) ...[
              // food
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionHead('🍽️', 'Food', p.saffron,
                      sub: 'Last 7 days',
                      trailing: logged.isEmpty ? null : Pill('🎯 $onT/${logged.length} on target', p.leaf)),
                  const SizedBox(height: 14),
                  Row(children: [
                    MacroDonut(avgT, size: 116),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        _stat(context, 'Avg calories', '${fmtInt(avgT.kcal)} kcal'),
                        const SizedBox(height: 8),
                        _stat(context, 'Avg protein', '${avgT.protein.round()} g'),
                        const SizedBox(height: 8),
                        MacroSplit(avg: avgT),
                      ]),
                    ),
                  ]),
                  const SizedBox(height: 14),
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
              // steps
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SectionHead('👟', 'Steps', p.water, sub: 'Last $_stepDays days'),
                  const SizedBox(height: 12),
                  Row(children: [
                    _DayTabs(value: _stepDays, onChanged: (v) => setState(() => _stepDays = v)),
                    const Spacer(),
                    if (bestI >= 0 && steps[bestI] > 0) Pill('🏅 Best: ${dayName(bestI)} · ${fmtInt(steps[bestI])}', p.leaf),
                  ]),
                  const SizedBox(height: 12),
                  Row(children: [
                    Expanded(child: _stat(context, 'Avg steps', fmtInt(avg(sDays.map((d) => d.steps.toDouble()))))),
                    Expanded(
                        child: _stat(context, 'Avg burned',
                            '${avg(sDays.map((d) => burnedOf(d, prof).total)).round()} kcal')),
                  ]),
                  const SizedBox(height: 4),
                  Muted('Days at goal: ${sDays.where((d) => d.steps >= stepGoalOf(prof)).length} of ${sDays.length}', size: 12.5),
                  const SizedBox(height: 12),
                  BarChart(
                    key: ValueKey('steps$_stepDays'),
                    labels: sLabels,
                    values: steps.map((v) => v.toDouble()).toList(),
                    goal: stepGoalOf(prof).toDouble(),
                    under: p.water,
                    over: p.leaf,
                    highlight: sDays.length - 1,
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              // history
              Panel(
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SectionHead('🗓️', 'History', p.leaf, sub: 'Calories per day'),
                  const SizedBox(height: 6),
                  if (hist.isEmpty) const Muted('Days you log food will show up here.'),
                  for (final d in (_histAll ? hist : hist.take(7))) HistoryRow(day: d, goals: g),
                  if (hist.length > 7)
                    TextButton(
                      onPressed: () => setState(() => _histAll = !_histAll),
                      child: Text(_histAll ? 'Show less' : 'Show all ${hist.length} days'),
                    ),
                ]),
              ),
            ],
          ]);
        },
      ),
    );
  }

  Widget _stat(BuildContext context, String label, String value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Muted(label, size: 12),
        Text(value, style: display(context, 20)),
      ]);
}


/// 7D / 30D switch for the steps chart.
class _DayTabs extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _DayTabs({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget b(String t, int v) => GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: value == v ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: value == v ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6)] : null,
            ),
            child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: value == v ? p.ink : p.muted)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [b('7D', 7), b('30D', 30)]),
    );
  }
}
