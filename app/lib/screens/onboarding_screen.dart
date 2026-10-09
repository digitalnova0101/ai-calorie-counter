import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../services/health_data.dart';
import '../widgets/graphics.dart';
import '../widgets/premium.dart';
import 'auth_screen.dart';
import 'onboarding_extras.dart';
import '../widgets/ui.dart';

/// Setup steps. Also used to edit the profile later (pass [initial]).
class OnboardingScreen extends StatefulWidget {
  final Profile? initial;
  const OnboardingScreen({super.key, this.initial});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  List<String> get _steps => [
        'about',
        'body',
        'activity',
        'goal',
        if (_goal != 'maintain') ...['target', 'date'],
        'allergies',
        'health',
        'plan',
      ];
  int _step = 0;
  late double _pace = widget.initial?.goal == 'gain' ? 0.25 : 0.5;
  late DateTime? _date = widget.initial != null && widget.initial!.targetDate.isNotEmpty
      ? DateTime.tryParse(widget.initial!.targetDate)
      : null;
  late final Set<String> _allergies = {...?widget.initial?.allergies};
  late final Set<String> _concerns = {...?widget.initial?.concerns};
  String? _error;
  bool _saving = false;

  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _age = TextEditingController(text: '${widget.initial?.age ?? 25}');
  late final _height =
      TextEditingController(text: (widget.initial?.heightCm ?? 170).toStringAsFixed(0));
  late final _weight =
      TextEditingController(text: _fmt(widget.initial?.weightKg ?? 70));
  late final _target = TextEditingController(
      text: _fmt((widget.initial?.targetWeightKg ?? 0) > 0 ? widget.initial!.targetWeightKg : 65));
  late String _sex = widget.initial?.sex ?? 'male';
  late String _activity = widget.initial?.activity ?? 'light';
  late String _goal = widget.initial?.goal ?? 'lose';

  final _gK = TextEditingController(), _gP = TextEditingController();
  final _gC = TextEditingController(), _gF = TextEditingController();
  final _gW = TextEditingController();

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _weight, _target, _gK, _gP, _gC, _gF, _gW]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  String? _validate() {
    final s = _steps[_step];
    if (s == 'body') {
      final a = _num(_age), h = _num(_height), w = _num(_weight);
      if (a < 13 || a > 100) return 'Enter an age between 13 and 100.';
      if (h < 120 || h > 230) return 'Enter a height between 120 and 230 cm.';
      if (w < 30 || w > 250) return 'Enter a weight between 30 and 250 kg.';
    }
    if (s == 'target') {
      final t = _num(_target), w = _num(_weight);
      if (t < 30 || t > 250) return 'Enter a target weight between 30 and 250 kg.';
      if (_goal == 'lose' && t >= w) return 'To lose weight, pick a goal below your weight now (${_fmt(w)} kg).';
      if (_goal == 'gain' && t <= w) return 'To gain weight, pick a goal above your weight now (${_fmt(w)} kg).';
    }
    return null;
  }

  void _next() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_steps[_step] == 'goal' && _goal != 'maintain' && _num(_target) <= 0) _target.text = _fmt(_num(_weight));
    if (_steps[_step] == 'target') _date ??= dateForPace(_num(_weight), _num(_target), _pace);
    if (_step + 1 < _steps.length && _steps[_step + 1] == 'plan') {
      final g = goalsWithPace(
          sex: _sex,
          age: _num(_age).round(),
          heightCm: _num(_height),
          weightKg: _num(_weight),
          activity: _activity,
          goal: _goal,
          paceKgWeek: _goal == 'maintain' ? 0 : paceOf(_num(_weight), _num(_target), _date));
      _gK.text = '${g.kcal}';
      _gP.text = '${g.protein}';
      _gC.text = '${g.carbs}';
      _gF.text = '${g.fat}';
      _gW.text = '${g.waterMl}';
    }
    if (_step < _steps.length - 1) {
      setState(() {
        _step++;
        _error = null;
      });
    } else {
      _save();
    }
  }

  Future<void> _save() async {
    int v(TextEditingController c, int lo, int hi, int fb) =>
        (int.tryParse(c.text.trim()) ?? fb).clamp(lo, hi);
    final weight = _num(_weight);
    final profile = Profile(
      name: _name.text.trim(),
      sex: _sex,
      age: _num(_age).round(),
      heightCm: _num(_height),
      weightKg: weight,
      activity: _activity,
      goal: _goal,
      targetWeightKg: _goal == 'maintain' ? weight : _num(_target),
      stepGoal: widget.initial?.stepGoal ?? 8000,
      stepGoalCustom: widget.initial?.stepGoalCustom ?? false,
      targetDate: _goal == 'maintain' || _date == null ? '' : dayKey(_date!),
      allergies: _allergies.where((x) => x != 'none').toList(),
      concerns: _concerns.where((x) => x != 'none').toList(),
      goals: Goals(
        kcal: v(_gK, 800, 6000, 2000),
        protein: v(_gP, 0, 400, 100),
        carbs: v(_gC, 0, 900, 250),
        fat: v(_gF, 0, 300, 60),
        waterMl: v(_gW, 500, 8000, 2500),
      ),
    );
    setState(() => _saving = true);
    try {
      await Db.instance.saveProfile(profile);
      if (widget.initial == null) await Db.instance.logWeight(dayKey(DateTime.now()), weight);
      if (!mounted) return;
      if (widget.initial != null) {
        Navigator.of(context).pop();
        toast(context, 'Profile updated');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'Could not save: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final s = _steps[_step];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(children: [
              Opacity(
                opacity: _step > 0 || widget.initial != null ? 1 : 0,
                child: SquareIconButton(Icons.chevron_left,
                    tooltip: 'Back',
                    onTap: () {
                      if (_step > 0) {
                        setState(() {
                          _step--;
                          _error = null;
                        });
                      } else if (widget.initial != null) {
                        Navigator.of(context).pop();
                      }
                    }),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: (_step + 1) / _steps.length),
                    duration: const Duration(milliseconds: 450),
                    curve: Curves.easeOutCubic,
                    builder: (_, v, __) => LinearProgressIndicator(
                        value: v, minHeight: 6, color: p.leaf, backgroundColor: p.steel),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Muted('${_step + 1}/${_steps.length}'),
            ]),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, a) => FadeTransition(
                opacity: a,
                child: SlideTransition(
                    position: Tween(begin: const Offset(0.08, 0), end: Offset.zero).animate(a),
                    child: child),
              ),
              child: ListView(
                key: ValueKey(s),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  ..._stepBody(s),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
                  ],
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _next,
                child: Text(s == 'plan'
                    ? (widget.initial == null ? 'Start tracking' : 'Save changes')
                    : 'Continue'),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _title(String t, [String? lead]) => Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: display(context, 24, weight: FontWeight.w700)),
          if (lead != null) ...[const SizedBox(height: 6), Muted(lead, size: 15)],
        ]),
      );

  Widget _choice(String emoji, String title, String? sub, bool on, VoidCallback onTap) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: on ? p.leaf.withValues(alpha: 0.09) : p.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: on ? p.leaf : p.line, width: 1.5),
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(14)),
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                if (sub != null) Muted(sub),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _dial(String label, TextEditingController c, String unit, double step) {
    final p = Palette.of(context);
    void bump(double d) {
      final v = (_num(c) + d);
      setState(() => c.text = _fmt((v * 10).roundToDouble() / 10));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        radius: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          NumberStepper(
            controller: c,
            decimal: true,
            suffix: unit,
            onChanged: (_) {},
            onMinus: () => bump(-step),
            onPlus: () => bump(step),
          ),
        ]),
      ),
    );
  }

  List<Widget> _stepBody(String s) {
    switch (s) {
      case 'about':
        return [
          _title("Let's build your plan", 'A few questions so we know how much you need each day.'),
          const Text('Your name', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 8),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              hintText: 'e.g. Rahul',
              hintStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Palette.of(context).muted.withValues(alpha: .6)),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 16, right: 10),
                child: Icon(Icons.person_outline_rounded, size: 26),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Palette.of(context).line, width: 1.5)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Palette.of(context).leaf, width: 2)),
            ),
          ),
          if (widget.initial == null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const AuthScreen(popOnDone: true))),
                child: const Text('Already have an account? Log in', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _choice('👨', 'Male', null, _sex == 'male', () => setState(() => _sex = 'male'))),
            const SizedBox(width: 10),
            Expanded(child: _choice('👩', 'Female', null, _sex == 'female', () => setState(() => _sex = 'female'))),
          ]),
        ];
      case 'body':
        return [
          _title('Your body', 'Used to work out your calorie burn and BMI.'),
          _dial('Age', _age, 'yrs', 1),
          _dial('Height', _height, 'cm', 1),
          _dial('Weight', _weight, 'kg', 0.5),
        ];
      case 'activity':
        const acts = [
          ['low', '🪑', 'Mostly sitting', 'Desk job, little walking'],
          ['light', '🚶', 'Lightly active', 'Walks, 1–3 workouts a week'],
          ['moderate', '🏃', 'Active', '3–5 workouts a week'],
          ['high', '🏋️', 'Very active', 'Daily hard training or physical work'],
        ];
        return [
          _title('How active are you?', 'Pick what fits a normal week.'),
          ...acts.map((a) => _choice(a[1], a[2], a[3], _activity == a[0], () => setState(() => _activity = a[0]))),
        ];
      case 'goal':
        const goals = [
          ['lose', '📉', 'Lose weight', 'About 0.5 kg a week'],
          ['maintain', '⚖️', 'Stay where I am', 'Keep my weight steady'],
          ['gain', '💪', 'Build muscle', 'Slow, lean gain'],
        ];
        return [
          _title("What's your goal?"),
          ...goals.map((g) => _choice(g[1], g[2], g[3], _goal == g[0], () => setState(() {
                _goal = g[0];
                _pace = g[0] == 'gain' ? 0.25 : 0.5;
                _date = null;
                final w = _num(_weight);
                if (g[0] == 'lose' && _num(_target) >= w) _target.text = _fmt((w * 0.9 * 2).roundToDouble() / 2);
                if (g[0] == 'gain' && _num(_target) <= w) _target.text = _fmt(((w + 4) * 2).roundToDouble() / 2);
              }))),
        ];
      case 'target':
        final tip = targetTip(_goal, _num(_weight), _num(_target), _num(_height));
        return [
          _title("What's your goal weight?", 'You are ${_fmt(_num(_weight))} kg now.'),
          _dial('Goal weight', _target, 'kg', 0.5),
          TargetTipBox(tip: tip),
        ];
      case 'date':
        return [
          _title('How fast do you want to go?', 'Pick a pace. We work out the date for you.'),
          PacePicker(
            lose: _goal == 'lose',
            weight: _num(_weight),
            target: _num(_target),
            date: _date,
            onDate: (d) => setState(() => _date = d),
          ),
        ];
      case 'allergies':
        return [
          _title('Any food allergies?', "We'll warn you when a scanned food may have them."),
          MultiChoice(
            choices: allergyChoices,
            selected: _allergies,
            onChanged: () => setState(() {}),
          ),
        ];
      case 'health':
        return [
          _title('Any health goals?', 'We tune your plan and the AI coach around these.'),
          MultiChoice(
            choices: concernChoices,
            selected: _concerns,
            onChanged: () => setState(() {}),
          ),
          const SizedBox(height: 8),
          const Muted('General guidance, not medical advice. If you have a condition, follow your doctor.', size: 12),
        ];
      default:
        final p = Palette.of(context);
        Widget tgt(String label, TextEditingController c, Color col, {String? sub}) => ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Container(width: 4, color: col),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(label,
                              style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 13)),
                          TextField(
                            controller: c,
                            keyboardType: TextInputType.number,
                            style: display(context, 20, weight: FontWeight.w700),
                            decoration: const InputDecoration(
                                isDense: true,
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(vertical: 4)),
                          ),
                          if (sub != null) Muted(sub, size: 12),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            );
        return [
          _title('Your custom plan is ready!', 'Tap any number to change it.'),
          if (_goal != 'maintain') ...[
            PlanGoalCard(
                lose: _goal == 'lose',
                weight: _num(_weight),
                target: _num(_target),
                heightCm: _num(_height),
                date: _date ?? dateForPace(_num(_weight), _num(_target), _goal == 'gain' ? 0.25 : 0.5)),
            const SizedBox(height: 12),
          ],
          Panel(child: BmiCard(weightKg: _num(_weight), heightCm: _num(_height))),
          const SizedBox(height: 12),
          tgt('Calories', _gK, p.saffron,
              sub: _goal == 'lose'
                  ? 'Below your daily burn, to reach your goal on time'
                  : _goal == 'gain'
                      ? 'Above your daily burn, for a lean gain'
                      : 'Matches your daily burn'),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: tgt('Protein g', _gP, p.leaf)),
            const SizedBox(width: 10),
            Expanded(child: tgt('Carbs g', _gC, p.wheat)),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: tgt('Fat g', _gF, p.chili)),
            const SizedBox(width: 10),
            Expanded(child: tgt('Water ml', _gW, p.water)),
          ]),
        ];
    }
  }
}
