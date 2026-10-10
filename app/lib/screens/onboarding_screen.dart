import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/goals.dart';
import '../services/units.dart';
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
  final int startStep; // used by layout tests
  const OnboardingScreen({super.key, this.initial, this.startStep = 0});
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
  late int _step = widget.startStep;
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
  // kg/cm or lb/ft-in. Fields hold what the user sees; getters below give metric.
  late bool _imperial = () {
    final u = widget.initial?.units ?? '';
    final v = u.isEmpty ? Units.deviceDefault() : u == 'imperial';
    Units.imperial = v;
    return v;
  }();
  late final _height =
      TextEditingController(text: (widget.initial?.heightCm ?? 170).toStringAsFixed(0));
  late final _ft = TextEditingController(text: '${_inchesOf(widget.initial?.heightCm ?? 170) ~/ 12}');
  late final _in = TextEditingController(text: '${_inchesOf(widget.initial?.heightCm ?? 170) % 12}');
  late final _weight = TextEditingController(text: _fmtW(widget.initial?.weightKg ?? 70));
  late final _target = TextEditingController(
      text: _fmtW((widget.initial?.targetWeightKg ?? 0) > 0 ? widget.initial!.targetWeightKg : 65));

  static int _inchesOf(double cm) => (cm / Units.cmPerIn).round();
  String _fmtW(double kg) =>
      _fmt(_imperial ? (kg * Units.lbPerKg).roundToDouble() : (kg * 2).roundToDouble() / 2);
  double get _hCm => _imperial ? (_num(_ft) * 12 + _num(_in)) * Units.cmPerIn : _hCm;
  double get _wKg => _imperial ? _wKg / Units.lbPerKg : _wKg;
  double get _tKg => _imperial ? _tKg / Units.lbPerKg : _tKg;

  void _setImperial(bool v) {
    if (v == _imperial) return;
    final h = _hCm, w = _wKg, t = _tKg;
    setState(() {
      _imperial = v;
      Units.imperial = v;
      _height.text = h.round().toString();
      _ft.text = '${_inchesOf(h) ~/ 12}';
      _in.text = '${_inchesOf(h) % 12}';
      _weight.text = _fmtW(w);
      _target.text = _fmtW(t);
    });
  }
  late String _sex = widget.initial?.sex ?? 'male';
  late String _activity = widget.initial?.activity ?? 'light';
  late String _goal = widget.initial?.goal ?? 'lose';

  final _gK = TextEditingController(), _gP = TextEditingController();
  final _gC = TextEditingController(), _gF = TextEditingController();
  final _gW = TextEditingController();

  static String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  void dispose() {
    for (final c in [_name, _age, _height, _ft, _in, _weight, _target, _gK, _gP, _gC, _gF, _gW]) {
      c.dispose();
    }
    super.dispose();
  }

  double _num(TextEditingController c) => double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  String? _validate() {
    final s = _steps[_step];
    if (s == 'body') {
      final a = _num(_age), h = _hCm, w = _wKg;
      if (a < 13 || a > 100) return 'Enter an age between 13 and 100.';
      if (h < 120 || h > 230) return 'Enter a height between ${Units.height(120)} and ${Units.height(230)}.';
      if (w < 30 || w > 250) return 'Enter a weight between ${Units.weight(30, 0)} and ${Units.weight(250, 0)}.';
    }
    if (s == 'target') {
      final t = _tKg, w = _wKg;
      if (t < 30 || t > 250) return 'Enter a target weight between ${Units.weight(30, 0)} and ${Units.weight(250, 0)}.';
      if (_goal == 'lose' && t >= w) return 'To lose weight, pick a goal below your weight now (${Units.weight(w)}).';
      if (_goal == 'gain' && t <= w) return 'To gain weight, pick a goal above your weight now (${Units.weight(w)}).';
    }
    return null;
  }

  void _next() {
    final err = _validate();
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (_steps[_step] == 'goal' && _goal != 'maintain' && _tKg <= 0) _target.text = _weight.text;
    if (_steps[_step] == 'target') _date ??= dateForPace(_wKg, _tKg, _pace);
    if (_step + 1 < _steps.length && _steps[_step + 1] == 'plan') {
      final g = goalsWithPace(
          sex: _sex,
          age: _num(_age).round(),
          heightCm: _hCm,
          weightKg: _wKg,
          activity: _activity,
          goal: _goal,
          paceKgWeek: _goal == 'maintain' ? 0 : paceOf(_wKg, _tKg, _date));
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
    final weight = _wKg;
    final profile = Profile(
      name: _name.text.trim(),
      sex: _sex,
      age: _num(_age).round(),
      heightCm: _hCm,
      weightKg: weight,
      activity: _activity,
      goal: _goal,
      targetWeightKg: _goal == 'maintain' ? weight : _tKg,
      stepGoal: widget.initial?.stepGoal ?? 8000,
      stepGoalCustom: widget.initial?.stepGoalCustom ?? false,
      units: _imperial ? 'imperial' : 'metric',
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

  Widget _unitSwitch() {
    final p = Palette.of(context);
    Widget opt(String t, bool imp) {
      final sel = _imperial == imp;
      return Expanded(
        child: Pressable(
          onTap: () => _setImperial(imp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              color: sel ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 8, offset: const Offset(0, 2))] : null,
            ),
            child: Text(t,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, color: sel ? p.ink : p.muted)),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.line.withValues(alpha: .6), borderRadius: BorderRadius.circular(15)),
      child: Row(children: [opt('kg · cm', false), opt('lb · ft', true)]),
    );
  }

  /// Height in feet and inches: one row like the others; tap the value for a scroll picker.
  Widget _heightImperial() {
    final p = Palette.of(context);
    final total = (_num(_ft) * 12 + _num(_in)).round().clamp(48, 90);
    void setTotal(int t) {
      final v = t.clamp(48, 90);
      setState(() {
        _ft.text = '${v ~/ 12}';
        _in.text = '${v % 12}';
      });
    }

    Widget btn(String t, VoidCallback f, String label) => Semantics(
          button: true,
          label: label,
          child: Pressable(
            onTap: f,
            child: Container(
              width: 52,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Text(t, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          ),
        );
    final big = display(context, 22, weight: FontWeight.w700);
    final unit = TextStyle(color: p.muted, fontWeight: FontWeight.w800, fontSize: 15);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Panel(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        radius: 18,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Height', style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Row(children: [
            btn('−', () => setTotal(total - 1), 'Shorter'),
            const SizedBox(width: 10),
            Expanded(
              child: Pressable(
                onTap: () => _pickHeight(total, setTotal),
                child: Container(
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line, width: 1.5),
                  ),
                  child: Text.rich(TextSpan(children: [
                    TextSpan(text: '${total ~/ 12}', style: big),
                    TextSpan(text: ' ft   ', style: unit),
                    TextSpan(text: '${total % 12}', style: big),
                    TextSpan(text: ' in', style: unit),
                  ])),
                ),
              ),
            ),
            const SizedBox(width: 10),
            btn('+', () => setTotal(total + 1), 'Taller'),
          ]),
        ]),
      ),
    );
  }

  Future<void> _pickHeight(int total, void Function(int) set) async {
    var ft = total ~/ 12, inch = total % 12;
    final ok = await showAppSheet<bool>(context, (ctx) {
      Widget wheel(int count, int start, int initial, String unit, ValueChanged<int> on) => Expanded(
            child: CupertinoPicker(
              itemExtent: 44,
              scrollController: FixedExtentScrollController(initialItem: initial - start),
              onSelectedItemChanged: (i) => on(i + start),
              children: [
                for (var v = start; v < start + count; v++)
                  Center(child: Text('$v $unit', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700))),
              ],
            ),
          );
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const H2('Your height'),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: Row(children: [
              wheel(4, 4, ft, 'ft', (v) => ft = v),
              wheel(12, 0, inch, 'in', (v) => inch = v),
            ]),
          ),
          const SizedBox(height: 12),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Done')),
        ]),
      );
    });
    if (ok == true) set(ft * 12 + inch);
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
          Text(label.isEmpty ? ' ' : label, style: TextStyle(color: p.muted, fontWeight: FontWeight.w700)),
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
              hintText: 'e.g. Alex',
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
          _unitSwitch(),
          const SizedBox(height: 12),
          _dial('Age', _age, 'yrs', 1),
          if (_imperial)
            _heightImperial()
          else
            _dial('Height', _height, 'cm', 1),
          _dial('Weight', _weight, Units.w, _imperial ? 1 : 0.5),
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
        final goals = [
          ['lose', '📉', 'Lose weight', _imperial ? 'About 1 lb a week' : 'About 0.5 kg a week'],
          ['maintain', '⚖️', 'Stay where I am', 'Keep my weight steady'],
          ['gain', '💪', 'Build muscle', 'Slow, lean gain'],
        ];
        return [
          _title("What's your goal?"),
          ...goals.map((g) => _choice(g[1], g[2], g[3], _goal == g[0], () => setState(() {
                _goal = g[0];
                _pace = g[0] == 'gain' ? 0.25 : 0.5;
                _date = null;
                final w = _wKg;
                if (g[0] == 'lose' && _tKg >= w) _target.text = _fmtW(w * 0.9);
                if (g[0] == 'gain' && _tKg <= w) _target.text = _fmtW(w + 4);
              }))),
        ];
      case 'target':
        final tip = targetTip(_goal, _wKg, _tKg, _hCm);
        return [
          _title("What's your goal weight?", 'You are ${Units.weight(_wKg)} now.'),
          _dial('Goal weight', _target, Units.w, _imperial ? 1 : 0.5),
          TargetTipBox(tip: tip),
        ];
      case 'date':
        return [
          _title('How fast do you want to go?', 'Pick a pace. We work out the date for you.'),
          PacePicker(
            lose: _goal == 'lose',
            weight: _wKg,
            target: _tKg,
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
                weight: _wKg,
                target: _tKg,
                heightCm: _hCm,
                date: _date ?? dateForPace(_wKg, _tKg, _goal == 'gain' ? 0.25 : 0.5)),
            const SizedBox(height: 12),
          ],
          Panel(child: BmiCard(weightKg: _wKg, heightCm: _hCm)),
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
