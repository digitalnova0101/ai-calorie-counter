import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/device.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../widgets/ui.dart';

// ============================================================
// Add / edit workout
// ============================================================
Future<void> showWorkoutSheet(BuildContext context,
        {required DateTime date, required Profile profile, Workout? editing}) =>
    showAppSheet(context, (_) => _WorkoutSheet(date: date, profile: profile, editing: editing));

class _WorkoutSheet extends StatefulWidget {
  final DateTime date;
  final Profile profile;
  final Workout? editing;
  const _WorkoutSheet({required this.date, required this.profile, this.editing});
  @override
  State<_WorkoutSheet> createState() => _WorkoutSheetState();
}

class _WorkoutSheetState extends State<_WorkoutSheet> {
  late String _type = widget.editing?.type ?? 'walk';
  late int _min = widget.editing?.min ?? 30;
  late final _ctrl = TextEditingController(text: '$_min');
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _setMin(int m) => setState(() {
        _min = m.clamp(0, 600);
        _ctrl.text = '$_min';
      });

  Future<void> _save() async {
    if (_min <= 0) return;
    setState(() => _saving = true);
    final kcal = workoutKcal(_type, _min, widget.profile.weightKg);
    final w = Workout(
      id: widget.editing?.id ?? newId('w'),
      type: _type,
      min: _min,
      kcal: kcal,
      time: widget.editing?.time ?? DateTime.now().millisecondsSinceEpoch,
    );
    final messenger = ScaffoldMessenger.of(context);
    await Db.instance.saveWorkout(dayKey(widget.date), w);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
        content: Text(widget.editing != null
            ? 'Workout updated'
            : '${workoutType(_type).name} added, ${kcal.round()} kcal burned')));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = workoutType(_type);
    final kcal = workoutKcal(_type, _min, widget.profile.weightKg);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        H2(widget.editing != null ? 'Edit workout' : 'Add workout'),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.95,
          children: workoutTypes.map((w) {
            final on = w.id == _type;
            return Pressable(
              onTap: () => setState(() => _type = w.id),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  color: on ? p.chili.withValues(alpha: 0.08) : p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? p.chili : p.line, width: 1.5),
                ),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(w.emoji, style: const TextStyle(fontSize: 26)),
                  const SizedBox(height: 4),
                  Text(w.name,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('How many minutes?', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            NumberStepper(
              controller: _ctrl,
              hint: 'Type minutes',
              suffix: 'min',
              onChanged: (v) => setState(() => _min = (int.tryParse(v) ?? 0).clamp(0, 600)),
              onMinus: () => _setMin(((_min / 5).round() * 5 - 5).clamp(5, 600)),
              onPlus: () => _setMin(((_min / 5).round() * 5 + 5).clamp(5, 600)),
            ),
            const SizedBox(height: 12),
            QuickChips<int>(
              values: const [10, 15, 30, 45, 60],
              selected: _min,
              label: (m) => '$m min',
              onTap: _setMin,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.chili.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.chili.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            Text(t.emoji, style: const TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                Muted('$_min min at ${widget.profile.weightKg.round()} kg'),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${kcal.round()}', style: display(context, 28, color: p.chili)),
              const Muted('kcal', size: 12),
            ]),
          ]),
        ),
        if (_type == 'walk' || _type == 'run') ...[
          const SizedBox(height: 8),
          const Muted(
              "If your phone already counted this walk in your steps, skip adding it so it isn't counted twice.",
              size: 12),
        ],
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
            onPressed: _saving || _min <= 0 ? null : _save,
            child: Text(widget.editing != null ? 'Save changes' : 'Add workout'),
          ),
        ),
      ]),
    );
  }
}

// ============================================================
// Steps
// ============================================================
Future<void> showStepsSheet(BuildContext context,
        {required DateTime date, required Profile profile, required int current}) =>
    showAppSheet(context, (_) => _StepsSheet(date: date, profile: profile, current: current));

class _StepsSheet extends StatefulWidget {
  final DateTime date;
  final Profile profile;
  final int current;
  const _StepsSheet({required this.date, required this.profile, required this.current});
  @override
  State<_StepsSheet> createState() => _StepsSheetState();
}

class _StepsSheetState extends State<_StepsSheet> {
  late int _steps = widget.current;
  late final _ctrl = TextEditingController(text: widget.current > 0 ? '${widget.current}' : '');
  bool _syncing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _set(int v) => setState(() {
        _steps = v.clamp(0, 100000);
        _ctrl.text = '$_steps';
      });

  Future<void> _sync() async {
    setState(() => _syncing = true);
    final ok = await StepsService.instance.connect();
    final n = ok ? await StepsService.instance.stepsFor(widget.date) : null;
    // also fill in the past 30 days in the background
    if (ok) StepsService.instance.syncRecent((d, v) => Db.instance.setSteps(dayKey(d), v), force: true);
    if (!mounted) return;
    setState(() => _syncing = false);
    if (n == null) {
      toast(context, ok
          ? 'No steps found. Open Health Connect and allow step access.'
          : 'Steps permission was not given. You can type your steps instead.');
    } else {
      _set(n);
    }
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    await Db.instance.setSteps(dayKey(widget.date), _steps);
    if (!mounted) return;
    Navigator.pop(context);
    messenger.showSnackBar(SnackBar(
        content: Text(widget.current < stepGoalOf(widget.profile) && _steps >= stepGoalOf(widget.profile)
            ? 'Step goal done! 🎉'
            : 'Steps saved')));
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const H2('Steps'),
        const SizedBox(height: 6),
        const Muted('Sync from Health Connect / Google Fit, or type the number from your step counter.'),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _syncing ? null : _sync,
          icon: _syncing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.sync),
          label: const Text('Sync from phone'),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Steps', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            NumberStepper(
              controller: _ctrl,
              hint: 'Type steps',
              onChanged: (v) => setState(() => _steps = (int.tryParse(v) ?? 0).clamp(0, 100000)),
              onMinus: () => _set(_steps - 500),
              onPlus: () => _set(_steps + 500),
            ),
            const SizedBox(height: 12),
            QuickChips<int>(
              values: const [2000, 5000, 8000, 10000, 12000],
              selected: _steps,
              label: fmtInt,
              onTap: _set,
              accent: p.water,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: p.water.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.water.withValues(alpha: 0.3)),
          ),
          child: Row(children: [
            const Text('👟', style: TextStyle(fontSize: 30)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${stepKm(_steps, widget.profile.heightCm).toStringAsFixed(1)} km',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const Muted('about'),
              ]),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('${stepKcal(_steps, widget.profile.weightKg).round()}', style: display(context, 28, color: p.chili)),
              const Muted('kcal burned', size: 12),
            ]),
          ]),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
            onPressed: _save,
            child: const Text('Save steps'),
          ),
        ),
      ]),
    );
  }
}
