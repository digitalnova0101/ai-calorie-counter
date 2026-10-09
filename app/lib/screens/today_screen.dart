import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/device.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/swipe_tile.dart';
import '../widgets/ui.dart';
import 'activity_sheets.dart';
import 'add_food.dart';
import 'coach_screen.dart';
import 'fasting_screen.dart';
import 'report_screen.dart';
import 'result_screen.dart';

class TodayScreen extends StatefulWidget {
  final Profile profile;
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  const TodayScreen({super.key, required this.profile, required this.date, required this.onDateChanged});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  late Stream<DayLog> _day;
  late String _key;
  int _streak = 0;
  int _lastMealCount = -1;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _subscribe();
    _loadStreak();
    _autoSyncSteps();
    // refresh the fasting countdown every 30 s
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && widget.profile.fast.start != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(TodayScreen old) {
    super.didUpdateWidget(old);
    if (dayKey(old.date) != dayKey(widget.date)) _subscribe();
  }

  void _subscribe() {
    _key = dayKey(widget.date);
    _day = Db.instance.dayStream(_key);
  }

  bool get _isToday => _key == dayKey(DateTime.now());

  Future<void> _loadStreak() async {
    try {
      final days = await Db.instance.recentDays(60);
      if (mounted) setState(() => _streak = streakFrom(days));
    } catch (_) {}
  }

  /// If the user connected Health Connect, pull today's steps quietly.
  Future<void> _autoSyncSteps() async {
    // today, plus the last 30 days once a day (so Progress shows past days too)
    await StepsService.instance.syncRecent((d, n) => Db.instance.setSteps(dayKey(d), n));
  }

  String _label() {
    final now = DateTime.now();
    if (_key == dayKey(now)) return 'Today';
    if (_key == dayKey(now.subtract(const Duration(days: 1)))) return 'Yesterday';
    return DateFormatShort.of(widget.date);
  }

  String _greeting() {
    final h = DateTime.now().hour;
    return h < 12 ? 'Good morning' : (h < 17 ? 'Good afternoon' : 'Good evening');
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final prof = widget.profile;
    final g = prof.goals;

    return StreamBuilder<DayLog>(
      stream: _day,
      builder: (context, snap) {
        if (snap.hasError) return Center(child: Text('Could not load this day.\n${snap.error}'));
        final log = snap.data ?? DayLog.empty(_key);
        if (snap.hasData && log.meals.length != _lastMealCount) {
          if (_lastMealCount != -1) WidgetsBinding.instance.addPostFrameCallback((_) => _loadStreak());
          _lastMealCount = log.meals.length;
        }
        final t = log.totals;
        final left = g.kcal - t.kcal;

        return RefreshIndicator(
          onRefresh: () async {
            await _loadStreak();
            await _autoSyncSteps();
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(16, 8, 16, bottomGap(context, 30)),
            children: [
              // ---------- header ----------
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Muted(_greeting()),
                    Text(prof.name.isEmpty ? 'Hello' : prof.name.split(' ').first,
                        style: display(context, 22, weight: FontWeight.w700)),
                  ]),
                ),
                if (_streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                        color: p.saffron.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(99)),
                    child: Text('🔥 $_streak',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                const SizedBox(width: 8),
                CoachTopButton(profile: prof),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                SquareIconButton(Icons.chevron_left,
                    tooltip: 'Previous day',
                    onTap: () => widget.onDateChanged(widget.date.subtract(const Duration(days: 1)))),
                Expanded(
                    child: Text(_label(),
                        textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                SquareIconButton(Icons.chevron_right,
                    tooltip: 'Next day',
                    onTap: _isToday ? null : () => widget.onDateChanged(widget.date.add(const Duration(days: 1)))),
              ]),
              const SizedBox(height: 14),

              // ---------- plate ----------
              Panel(
                radius: 30,
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 18),
                gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [p.heroA, p.heroB]),
                child: Column(children: [
                  Ring(
                    value: g.kcal == 0 ? 0.0 : t.kcal / g.kcal,
                    color: left < 0 ? p.chili : p.saffron,
                    size: 230,
                    stroke: 15,
                    ticks: 60,
                    duration: const Duration(milliseconds: 1300),
                    child: Container(
                      width: 168,
                      height: 168,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [p.surface, p.plateIn]),
                      ),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        CountUp(left.abs(), style: display(context, 40)),
                        const SizedBox(height: 2),
                        Muted(left < 0 ? 'kcal over' : 'kcal left', size: 14),
                        const SizedBox(height: 4),
                        Muted('${t.kcal.round()} eaten of ${g.kcal}', size: 12),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                    MacroRing(label: 'Protein', value: t.protein, goal: g.protein, color: p.leaf),
                    MacroRing(label: 'Carbs', value: t.carbs, goal: g.carbs, color: p.wheat),
                    MacroRing(label: 'Fat', value: t.fat, goal: g.fat, color: p.chili),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),

              // ---------- quick scan ----------
              Row(children: [
                Expanded(
                    child: _QuickButton(
                        icon: Icons.photo_camera_outlined,
                        title: 'Scan food',
                        sub: 'Camera or gallery',
                        color: p.saffron,
                        onTap: () => chooseAndScan(context, widget.date))),
                const SizedBox(width: 10),
                Expanded(
                    child: _QuickButton(
                        icon: Icons.qr_code_scanner,
                        title: 'Barcode',
                        sub: 'Packaged food',
                        color: p.water,
                        onTap: () => openBarcode(context, widget.date))),
              ]),
              const SizedBox(height: 12),

              // ---------- calories burned ----------
              _BurnedCard(date: widget.date, profile: prof, log: log),
              const SizedBox(height: 12),

              // ---------- water ----------
              Panel(
                child: Row(children: [
                  WaterGlass(g.waterMl == 0 ? 0.0 : log.waterMl / g.waterMl),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const H2('Water'),
                      () {
                        final goalGl = math.max(1, (g.waterMl / 250).ceil());
                        final gl = log.waterMl ~/ 250, extra = math.max(0, gl - goalGl);
                        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(
                                text: '${(log.waterMl / 1000).toStringAsFixed(2)} L',
                                style: TextStyle(fontWeight: FontWeight.w800, color: p.ink)),
                            TextSpan(
                                text: log.waterMl >= g.waterMl ? '  Goal done ✓' : ' of ${(g.waterMl / 1000).toStringAsFixed(2)} L',
                                style: TextStyle(color: log.waterMl >= g.waterMl ? p.leaf : p.muted, fontWeight: FontWeight.w700)),
                          ])),
                          const SizedBox(height: 8),
                          // one icon per 250 ml glass up to the goal; extra glasses show as "+N"
                          Row(children: [
                            Flexible(
                              child: Wrap(
                                spacing: 3,
                                runSpacing: 3,
                                children: List.generate(
                                  goalGl,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: 10,
                                    height: 15,
                                    decoration: BoxDecoration(
                                      color: i < gl ? p.water : p.steel,
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(2), bottom: Radius.circular(4)),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            if (extra > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                    color: p.leaf.withValues(alpha: .15), borderRadius: BorderRadius.circular(99)),
                                child: Text('+$extra',
                                    style: TextStyle(color: p.leaf, fontWeight: FontWeight.w800, fontSize: 12)),
                              ),
                            ],
                          ]),
                        ]);
                      }(),
                    ]),
                  ),
                  SquareIconButton(Icons.remove,
                      tooltip: 'Remove a glass',
                      onTap: log.waterMl <= 0
                          ? null
                          : () {
                              HapticFeedback.selectionClick();
                              Db.instance.addWater(_key, -250);
                            }),
                  const SizedBox(width: 8),
                  SquareIconButton(Icons.add,
                      tooltip: 'Add a glass, 250 ml',
                      fill: p.water,
                      iconColor: Colors.white,
                      onTap: () {
                        HapticFeedback.lightImpact();
                        final before = log.waterMl;
                        Db.instance.addWater(_key, 250); // updates the screen at once
                        if (before < g.waterMl && before + 250 >= g.waterMl) toast(context, 'Water goal done! 💧');
                      }),
                ]),
              ),
              const SizedBox(height: 12),

              // ---------- fasting ----------
              _FastCard(fast: prof.fast),
              const SizedBox(height: 12),

              // ---------- score ----------
              _ScoreCard(log: log, profile: prof, date: widget.date),
              const SizedBox(height: 12),

              // ---------- meals ----------
              if (log.meals.isEmpty)
                Panel(
                  child: Column(children: [
                    const SizedBox(height: 8),
                    const Text('🍽️', style: TextStyle(fontSize: 56)),
                    const SizedBox(height: 8),
                    const H2('Your plate is empty'),
                    const SizedBox(height: 4),
                    Muted(_isToday
                        ? 'Tap the orange button to scan your first meal of the day.'
                        : 'Nothing was logged on this day.',
                        align: TextAlign.center),
                    const SizedBox(height: 14),
                    FilledButton(
                      style: FilledButton.styleFrom(backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
                      onPressed: () => showAddFoodSheet(context, widget.date),
                      child: const Text('Scan a meal'),
                    ),
                  ]),
                )
              else
                ...mealTypes.where((ty) => log.meals.any((m) => m.type == ty)).map((ty) {
                  final ms = log.meals.where((m) => m.type == ty).toList()
                    ..sort((a, b) => a.time.compareTo(b.time));
                  final tot = Totals();
                  for (final m in ms) {
                    tot.addItems(m.items);
                  }
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Panel(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        Row(children: [
                          Container(
                            width: 36,
                            height: 36,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
                            child: Text(mealEmoji[ty] ?? '🍽️', style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(ty, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                          Text('${tot.kcal.round()}',
                              style: display(context, 17, weight: FontWeight.w700, color: p.saffron)),
                          const SizedBox(width: 4),
                          const Muted('kcal', size: 12),
                        ]),
                        const SizedBox(height: 10),
                        for (final m in ms) ...[
                          SwipeTile(
                            key: ValueKey(m.id),
                            onEdit: () => _editMeal(m),
                            onDelete: () => _deleteMeal(m),
                            child: _MealRow(meal: m),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ]),
                    ),
                  );
                }),
              if (log.meals.isNotEmpty)
                const Muted('Tip: swipe a meal left to edit or delete it', size: 12, align: TextAlign.center),
            ],
          ),
        );
      },
    );
  }

  void _editMeal(MealEntry m) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ResultScreen(
          date: widget.date,
          source: m.source,
          items: m.items.map((i) => i.copy()).toList(),
          dish: m.dish,
          thumb: m.thumb,
          editing: m,
        ),
      ));

  Future<void> _deleteMeal(MealEntry m) async {
    final key = _key;
    await Db.instance.removeMeal(key, m.id);
    if (!mounted) return;
    toast(context, 'Meal deleted', action: 'Undo', onAction: () => Db.instance.addMeal(key, m));
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String title, sub;
  final Color color;
  final VoidCallback onTap;
  const _QuickButton({required this.icon, required this.title, required this.sub, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => Panel(
        onTap: onTap,
        radius: 20,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Muted(sub, size: 12),
            ]),
          ),
        ]),
      );
}

class _MealRow extends StatelessWidget {
  final MealEntry meal;
  const _MealRow({required this.meal});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = Totals.of(meal.items);
    final all = (s.protein * 4 + s.carbs * 4 + s.fat * 9);
    final sub = meal.items.length > 1
        ? '${meal.items.length} items'
        : (meal.items.isEmpty ? '' : (meal.items.first.portionLabel ?? meal.items.first.portion));
    Widget seg(double v, Color c) => Expanded(
        flex: all <= 0 ? 1 : (v / all * 1000).round().clamp(1, 1000),
        child: Container(height: 5, color: c));
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Row(children: [
        MealThumb(meal),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meal.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
            Muted('${sub.isNotEmpty ? '$sub, ' : ''}P ${s.protein.round()}g C ${s.carbs.round()}g F ${s.fat.round()}g', size: 12),
            const SizedBox(height: 6),
            SizedBox(
              width: 90,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Row(children: [seg(s.protein * 4, p.leaf), seg(s.carbs * 4, p.wheat), seg(s.fat * 9, p.chili)]),
              ),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        Text('${s.kcal.round()}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      ]),
    );
  }
}

class _BurnedCard extends StatelessWidget {
  final DateTime date;
  final Profile profile;
  final DayLog log;
  const _BurnedCard({required this.date, required this.profile, required this.log});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final b = burnedOf(log, profile);
    final ws = [...log.workouts]..sort((a, c) => a.time.compareTo(c.time));
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: p.chili.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(15)),
            child: const Text('🔥', style: TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Muted('Calories burned'),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                CountUp(b.total, style: display(context, 26)),
                const SizedBox(width: 4),
                const Muted('kcal'),
              ]),
            ]),
          ),
          PillButton('+ Workout', onTap: () => showWorkoutSheet(context, date: date, profile: profile)),
        ]),
        const SizedBox(height: 12),
        Pressable(
          onTap: () => showStepsSheet(context, date: date, profile: profile, current: log.steps),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
            child: Row(children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
                child: const Text('👟', style: TextStyle(fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('Steps', style: TextStyle(fontWeight: FontWeight.w800))),
                    Muted('${fmtInt(log.steps)} / ${fmtInt(stepGoalOf(profile))}'),
                  ]),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(9),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (log.steps / stepGoalOf(profile)).clamp(0.0, 1.0)),
                      duration: const Duration(milliseconds: 1000),
                      curve: Curves.easeOutCubic,
                      builder: (_, v, __) => LinearProgressIndicator(
                          value: v,
                          minHeight: 7,
                          color: log.steps >= stepGoalOf(profile) ? p.leaf : p.water,
                          backgroundColor: p.steel),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Muted(log.steps > 0
                      ? '${stepKm(log.steps, profile.heightCm).toStringAsFixed(1)} km, tap to update'
                      : 'Tap to sync or enter steps',
                      size: 12),
                ]),
              ),
              const SizedBox(width: 10),
              Text('${b.stepKcal.round()}', style: TextStyle(color: p.chili, fontWeight: FontWeight.w800, fontSize: 16)),
            ]),
          ),
        ),
        if (ws.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            const Expanded(child: Muted('Workouts', size: 12.5)),
            Muted('${ws.length} workout${ws.length == 1 ? '' : 's'}, ${b.workoutKcal.round()} kcal', size: 12.5),
          ]),
          const SizedBox(height: 8),
          for (final w in ws) ...[
            SwipeTile(
              key: ValueKey(w.id),
              background: p.bg,
              onEdit: () => showWorkoutSheet(context, date: date, profile: profile, editing: w),
              onDelete: () async {
                final key = dayKey(date);
                await Db.instance.removeWorkout(key, w.id);
                if (context.mounted) {
                  toast(context, 'Workout deleted', action: 'Undo', onAction: () => Db.instance.saveWorkout(key, w));
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(12)),
                    child: Text(workoutType(w.type).emoji, style: const TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(workoutType(w.type).name, style: const TextStyle(fontWeight: FontWeight.w800)),
                      Muted('${w.min} min', size: 12),
                    ]),
                  ),
                  Text('${w.kcal.round()} kcal', style: TextStyle(color: p.chili, fontWeight: FontWeight.w800)),
                ]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ]),
    );
  }
}

class _FastCard extends StatelessWidget {
  final FastState fast;
  const _FastCard({required this.fast});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final on = fast.start != null;
    final goal = Duration(hours: fast.plan);
    final el = on ? DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(fast.start!)) : Duration.zero;
    final frac = on ? el.inSeconds / goal.inSeconds : 0.0;
    final done = on && el >= goal;
    final end = on ? DateTime.fromMillisecondsSinceEpoch(fast.start!).add(goal) : null;
    String hm(Duration d) => '${d.inHours}h ${(d.inMinutes % 60).toString().padLeft(2, '0')}m';
    return Panel(
      onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => FastingScreen(fast: fast))),
      child: Row(children: [
        Ring(
          value: frac,
          color: done ? p.leaf : p.saffron,
          size: 58,
          stroke: 6,
          child: Text(on ? '${(frac.clamp(0.0, 1.0) * 100).round()}%' : '⏱',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            H2(!on ? 'Intermittent fasting' : (done ? 'Fasting goal reached' : 'Fasting')),
            Muted(!on
                ? '${fast.plan}:${24 - fast.plan} plan, not started'
                : (done ? '${hm(el)} so far' : '${hm(goal - el)} left, ends ${fmtClock(end!)}')),
          ]),
        ),
        PillButton(on ? 'End' : 'Start', onTap: () async {
          final msg = await toggleFast(fast);
          if (context.mounted) toast(context, msg);
        }),
      ]),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  final DayLog log;
  final Profile profile;
  final DateTime date;
  const _ScoreCard({required this.log, required this.profile, required this.date});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = dayScore(log, profile);
    final sc = s.hasData ? s.score : 0;
    final (name, col) = gradeOf(sc);
    return Panel(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => ReportScreen(profile: profile, date: date))),
      child: Row(children: [
        Ring(
          value: sc / 100,
          color: col(p),
          size: 58,
          stroke: 6,
          child: Text('$sc', style: display(context, 15, weight: FontWeight.w800)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const H2("Today's score"),
            Muted(s.hasData ? '$name. Tap for your report card' : 'Log food to get your score'),
          ]),
        ),
        Icon(Icons.chevron_right, color: p.muted),
      ]),
    );
  }
}
