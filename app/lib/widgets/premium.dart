// Premium cards for the Progress tab (same design as the website).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/db.dart';
import '../services/goals.dart';
import '../theme.dart';
import 'graphics.dart';
import 'ui.dart';
import '../services/units.dart';

Color tint(Color c, double a, Color on) => Color.alphaBlend(c.withValues(alpha: a), on);

String kg(double v) => Units.weight(v);

/// Small grey label in capitals with wide letter spacing.
class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.6, color: Palette.of(context).muted));
}

/// Coloured pill such as "Overweight" or "26%".
class Pill extends StatelessWidget {
  final String text;
  final Color color;
  final bool solid;
  const Pill(this.text, this.color, {super.key, this.solid = false});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: solid ? color : tint(color, 0.13, p.surface),
        borderRadius: BorderRadius.circular(99),
        border: solid ? null : Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(text,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: solid ? Colors.white : color)),
    );
  }
}

/// Grey tile with a small label and a value.
class StatTile extends StatelessWidget {
  final String label, value;
  final String? icon;
  final Color? iconColor, valueColor;
  const StatTile(this.label, this.value, {super.key, this.icon, this.iconColor, this.valueColor});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null)
          Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(bottom: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
                color: tint(iconColor ?? p.leaf, 0.14, p.surface), borderRadius: BorderRadius.circular(9)),
            child: Text(icon!, style: const TextStyle(fontSize: 14)),
          ),
        Muted(label, size: 12),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: valueColor ?? p.ink)),
        ),
      ]),
    );
  }
}

/// Section heading with a coloured icon box.
class SectionHead extends StatelessWidget {
  final String icon, title;
  final String? sub;
  final Color color;
  final Widget? trailing;
  const SectionHead(this.icon, this.title, this.color, {super.key, this.sub, this.trailing});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Row(children: [
      Container(
        width: 42,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: tint(color, 0.14, p.surface), borderRadius: BorderRadius.circular(14)),
        child: Text(icon, style: const TextStyle(fontSize: 19)),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          H2(title),
          if (sub != null) Muted(sub!),
        ]),
      ),
      if (trailing != null) trailing!,
    ]);
  }
}

/// Soft note box (yellow or green).
class NoteBox extends StatelessWidget {
  final String icon;
  final String bold, text;
  final Color color;
  const NoteBox(this.icon, this.bold, this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: tint(color, 0.11, p.surface),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint(color, 0.35, p.line)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(icon, style: const TextStyle(fontSize: 17)),
        const SizedBox(width: 10),
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: '$bold ', style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: text),
            ]),
            style: TextStyle(fontSize: 13.5, height: 1.45, color: p.ink),
          ),
        ),
      ]),
    );
  }
}

// =====================================================================
// BMI card
// =====================================================================
class BmiCard extends StatelessWidget {
  final double weightKg, heightCm;
  const BmiCard({super.key, required this.weightKg, required this.heightCm});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final b = bmi(weightKg, heightCm), band = bmiBandOf(b), bc = band.color(p);
    final bi = bmiBands.indexOf(band);
    final edges = bmiEdges;
    final pos = (bi + ((b.clamp(edges[bi], edges[bi + 1]) - edges[bi]) / (edges[bi + 1] - edges[bi]))).clamp(0.0, 4.0);
    final left = (pos / 4).clamp(0.04, 0.96);
    final h = heightCm / 100, minW = 18.5 * h * h, maxW = (bmiHealthyMax - 0.1) * h * h;
    final over = weightKg - maxW, under = minW - weightKg;
    final msg = over > 0
        ? "You're ${kg(over)} above your healthy range."
        : under > 0
            ? "You're ${kg(under)} below your healthy range."
            : "You're in the healthy range for your height. Keep it up!";

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: tint(bc, 0.22, p.line)),
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [tint(bc, 0.16, p.surface), tint(bc, 0.04, p.surface), p.surface],
          ),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Eyebrow('Body mass index')),
            Pill('● ${band.name}', bc),
          ]),
          const SizedBox(height: 8),
          Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
            CountUp(b, style: display(context, 46, weight: FontWeight.w600), format: (v) => v.toStringAsFixed(1)),
            const SizedBox(width: 8),
            Text('BMI', style: TextStyle(fontWeight: FontWeight.w700, color: p.muted)),
          ]),
          const SizedBox(height: 6),
          Text(msg, style: TextStyle(color: p.muted, fontSize: 14.5, height: 1.4)),
          const SizedBox(height: 14),
          _BmiScale(left: left, value: b),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: StatTile('Healthy range', '${Units.toW(minW).toStringAsFixed(0)}–${Units.toW(maxW).toStringAsFixed(0)} ${Units.w}')),
        const SizedBox(width: 10),
        Expanded(
          child: StatTile(over > 0 || under > 0 ? 'To reach it' : 'Your weight',
              over > 0 ? '−${kg(over)}' : under > 0 ? '+${kg(under)}' : kg(weightKg),
              valueColor: over > 0 || under > 0 ? null : p.leaf),
        ),
      ]),
      const SizedBox(height: 8),
      Muted('$bmiRangesName · ${Units.height(heightCm)}', size: 12),
    ]);
  }
}

class _BmiScale extends StatelessWidget {
  final double left, value;
  const _BmiScale({required this.left, required this.value});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (context, box) {
      final w = box.maxWidth;
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.04, end: left),
        duration: const Duration(milliseconds: 1300),
        curve: Curves.easeOutBack,
        builder: (context, v, _) {
          final x = w * v;
          return SizedBox(
            height: 78,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 36,
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(
                        colors: [p.water, p.water, p.leaf, p.leaf, p.wheat, p.wheat, p.chili, p.chili],
                        stops: const [0, .16, .31, .44, .54, .68, .82, 1]),
                  ),
                ),
              ),
              Positioned(
                left: x - 28,
                top: 0,
                width: 56,
                child: Column(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: p.ink, borderRadius: BorderRadius.circular(8)),
                    child: Text(value.toStringAsFixed(1),
                        style: TextStyle(color: p.surface, fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const SizedBox(height: 5),
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: p.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: p.ink, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .25), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                  ),
                ]),
              ),
              for (final (t, f) in [('Under', 0.0), ('18.5', .25), (bmiEdges[2].toStringAsFixed(0), .5), (bmiEdges[3].toStringAsFixed(0), .75), ('Obese', 1.0)])
                Positioned(
                  top: 56,
                  left: f == 0 ? 0 : (f == 1 ? null : w * f - 16),
                  right: f == 1 ? 0 : null,
                  width: f == 0 || f == 1 ? null : 32,
                  child: Text(t,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: p.muted)),
                ),
            ]),
          );
        },
      );
    });
  }
}

// =====================================================================
// Goal progress card
// =====================================================================
class GoalProgressCard extends StatelessWidget {
  final Profile profile;
  final List<WeightEntry> weights;
  final VoidCallback onFixGoal;
  const GoalProgressCard({super.key, required this.profile, required this.weights, required this.onFixGoal});

  Widget _paceTag(BuildContext context, double? v, bool lose) {
    final p = Palette.of(context);
    if (v == null) return const SizedBox.shrink();
    final safeHi = lose ? 1.0 : 0.5;
    if (v > safeHi) return Pill('Too fast', p.chili, solid: true);
    if (v < 0) return Pill(lose ? 'Going up' : 'Going down', p.wheat, solid: true);
    if (v < 0.25) return Pill('Slow', p.water, solid: true);
    return Pill('Safe ✓', p.leaf, solid: true);
  }

  Widget _paceRow(BuildContext context, String label, String value, Widget tag) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Muted(label, size: 12.5),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ]),
        ),
        tag,
      ]);

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final m = GoalMath.of(profile, weights);
    if (m == null) return const SizedBox.shrink();
    if (m.wrongSide) {
      return Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHead('⚠️', 'Check your goal', p.wheat,
              sub: 'Your goal is to ${m.lose ? 'lose' : 'gain'} weight, but your goal weight (${kg(m.target)}) is '
                  '${m.lose ? 'higher' : 'lower'} than your weight now (${kg(m.cur)}).'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onFixGoal, child: const Text('Update my goal')),
        ]),
      );
    }
    final lose = m.lose;
    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('Goal progress'),
              const SizedBox(height: 4),
              Text(m.doneKg < 0.05 ? kg(0) : '${lose ? '−' : '+'}${kg(m.doneKg)}',
                  style: display(context, 32, weight: FontWeight.w700)),
              const SizedBox(height: 2),
              Muted('${lose ? 'lost' : 'gained'} of your ${kg(m.totalKg)} goal · ${kg(m.leftKg)} to go'),
            ]),
          ),
          Pill('${m.pct.round()}%', p.leaf),
        ]),
        const SizedBox(height: 16),
        MilestoneBar(pct: m.pct),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatTile('Start', kg(m.start), icon: '🚩', iconColor: lose ? p.saffron : p.water)),
          const SizedBox(width: 8),
          Expanded(child: StatTile('Now', kg(m.cur), icon: '📍', iconColor: p.ink)),
          const SizedBox(width: 8),
          Expanded(child: StatTile('Goal', kg(m.target), icon: '🎯', iconColor: p.leaf, valueColor: p.leaf)),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: Text.rich(TextSpan(children: [
              TextSpan(text: fmtInt(m.doneKg * kcalPerKg), style: const TextStyle(fontWeight: FontWeight.w800)),
              TextSpan(text: ' kcal ${lose ? 'burned' : 'added'} so far', style: TextStyle(color: p.muted)),
            ])),
          ),
          Text.rich(TextSpan(children: [
            TextSpan(text: fmtInt(m.leftKg * kcalPerKg), style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(text: ' kcal to go', style: TextStyle(color: p.muted)),
          ])),
        ]),
        const SizedBox(height: 12),
        _paceRow(context, "Your plan's pace", Units.pace(m.perWeek), _paceTag(context, m.perWeek, lose)),
        const SizedBox(height: 10),
        _paceRow(
            context,
            'Your real pace (from weigh-ins)',
            m.realPace == null ? 'Log a week of weights' : Units.pace(m.realPace!.abs()),
            _paceTag(context, m.realPace, lose)),
        const SizedBox(height: 14),
        if (lose) ...[
          NoteBox('⚖️', Units.imperial ? '1 lb of body fat ≈ 3,500 kcal.' : '1 kg of body fat ≈ 7,700 kcal.',
              '${Units.imperial ? 'To lose 1 lb you need to burn about 3,500 kcal' : 'To lose 1 kg you need to burn about 7,700 kcal'} more than you eat. Your goal of ${kg(m.totalKg)} means about ${fmtInt(m.totalKg * kcalPerKg)} kcal in total.',
              p.wheat),
          const SizedBox(height: 10),
          NoteBox('✅', Units.imperial ? '1 lb a week is a safe weight loss.' : '0.5 kg a week is a safe weight loss.',
              "That's a deficit of about 500 kcal a day. Up to ${Units.imperial ? '2 lb' : '1 kg'} a week is the safe upper limit; faster than that can cost muscle and is hard to keep off.",
              p.leaf),
        ] else ...[
          NoteBox('⚖️', Units.imperial ? 'Gaining 1 lb needs about 3,500 kcal' : 'Gaining 1 kg needs about 7,700 kcal',
              'more eaten than burned. With strength training, more of that goes into muscle instead of fat. Your goal of ${kg(m.totalKg)} means about ${fmtInt(m.totalKg * kcalPerKg)} kcal extra in total.',
              p.wheat),
          const SizedBox(height: 10),
          NoteBox('✅', Units.imperial ? '0.5 to 1 lb a week is a healthy, lean gain.' : '0.25 to 0.5 kg a week is a healthy, lean gain.',
              "That's a surplus of about 250 to 500 kcal a day plus enough protein. Gaining faster mostly adds fat.",
              p.leaf),
        ],
      ]),
    );
  }
}

/// 25 / 50 / 75 / 🏆 checkpoints with a glowing fill.
class MilestoneBar extends StatelessWidget {
  final double pct;
  const MilestoneBar({super.key, required this.pct});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: pct / 100),
          duration: const Duration(milliseconds: 1300),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => SizedBox(
            height: 50,
            child: Stack(clipBehavior: Clip.none, children: [
              Positioned(
                left: 0,
                right: 0,
                top: 10,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(color: p.plateTrack, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              Positioned(
                left: 0,
                top: 10,
                width: w * v,
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(99),
                    gradient: LinearGradient(colors: [p.saffron, p.leaf]),
                    boxShadow: [BoxShadow(color: p.leaf.withValues(alpha: .5), blurRadius: 10)],
                  ),
                ),
              ),
              for (final mk in const [25, 50, 75, 100])
                Positioned(
                  left: w * mk / 100 - 16,
                  top: 0,
                  width: 32,
                  child: Column(children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: pct >= mk ? p.leaf : p.surface,
                        border: Border.all(color: pct >= mk ? p.leaf : p.plateTrack, width: 2.5),
                      ),
                      child: Text(mk == 100 ? '🏆' : (pct >= mk ? '✓' : ''),
                          style: TextStyle(fontSize: mk == 100 ? 13 : 12, color: Colors.white, fontWeight: FontWeight.w900)),
                    ),
                    const SizedBox(height: 4),
                    Text('$mk%', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: p.muted)),
                  ]),
                ),
            ]),
          ),
        );
      }),
    );
  }
}

// =====================================================================
// Weight plan card ("Your weight-loss plan")
// =====================================================================
class WeightPlanCard extends StatelessWidget {
  final Profile profile;
  final List<WeightEntry> weights;
  final DayLog? today;
  const WeightPlanCard({super.key, required this.profile, required this.weights, this.today});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final m = GoalMath.of(profile, weights);
    if (m == null || m.wrongSide) return const SizedBox.shrink();
    final lose = m.lose;
    if (m.leftKg <= 0) {
      return Panel(
        child: SectionHead('🏆', 'Goal reached!', p.leaf,
            sub: "You're at ${kg(m.cur)}. Set a new goal in Profile, or switch to \"Stay where I am\"."),
      );
    }
    final word = lose ? 'deficit' : 'surplus';
    final td = profile.targetDate.isNotEmpty ? DateTime.tryParse(profile.targetDate) : null;
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final dateTxt = td == null ? '' : ' by ${td.day} ${months[td.month - 1]} ${td.year}';
    final stepsExtra = m.fromMove / math.max(0.0001, stepKcal(1, m.cur));
    int minsFor(String t) => (m.fromMove / math.max(0.0001, workoutKcal(t, 1, m.cur))).ceil();

    // today so far: body (BMR x 1.2) + activity − eaten
    Widget todayRow() {
      final d = today;
      final eaten = d?.totals.kcal ?? 0;
      if (d == null || eaten <= 0) return Muted("Log today's food to see your $word for the day.");
      final burned = burnedOf(d, profile).total, body = bmrOf(profile, m.cur) * 1.2;
      final v = lose ? body + burned - eaten : eaten - (body + burned);
      final ok = v >= m.needed;
      final col = ok ? p.leaf : (v > 0 ? p.wheat : p.chili);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Text('Today so far', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15))),
          Text(v > 0 ? '${fmtInt(v)} kcal $word${ok ? ' ✓' : ''}' : 'No $word yet',
              style: TextStyle(fontWeight: FontWeight.w800, color: col)),
        ]),
        const SizedBox(height: 6),
        _Bar(frac: (v / math.max(1, m.needed)).clamp(0.0, 1.0).toDouble(), color: ok ? p.leaf : p.saffron),
        const SizedBox(height: 4),
        Muted('Body ${fmtInt(body)} + steps and workouts ${fmtInt(burned)} − ${fmtInt(eaten)} eaten. Target: ${fmtInt(m.needed)} kcal.',
            size: 12),
      ]);
    }

    return Panel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHead(lose ? '🎯' : '💪', 'Your weight-${lose ? 'loss' : 'gain'} plan', p.leaf,
            sub: '${lose ? 'Lose' : 'Gain'} ${kg(m.leftKg)} more$dateTxt'),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: StatTile('Total to ${lose ? 'burn' : 'add'}', '${fmtInt(m.leftKg * kcalPerKg)} kcal')),
          const SizedBox(width: 8),
          Expanded(child: StatTile('Days left', '${m.daysLeft} days')),
          const SizedBox(width: 8),
          Expanded(child: StatTile('Daily $word', '${fmtInt(m.needed)} kcal', valueColor: p.leaf)),
        ]),
        const SizedBox(height: 14),
        Text('How to hit ${fmtInt(m.needed)} kcal a day', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: SizedBox(
            height: 12,
            child: Row(children: [
              Expanded(flex: math.max(1, (m.fromFood * 100).round()), child: Container(color: p.saffron)),
              if (m.fromMove > 1) Expanded(flex: math.max(1, (m.fromMove * 100).round()), child: Container(color: p.water)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        _dotRow(context, p.saffron, 'Food: eat ${fmtInt(profile.goals.kcal)} kcal a day',
            "That's ${fmtInt(m.fromFood)} ${lose ? 'less' : 'more'} than the ${fmtInt(m.tdee)} your body uses."),
        const SizedBox(height: 10),
        if (!lose)
          _dotRow(context, p.water, 'Strength training 3–4 times a week',
              'So the extra calories go to muscle. Eat about ${profile.goals.protein} g protein a day.')
        else if (m.fromMove > 1)
          _dotRow(context, p.water, 'Movement: burn ${fmtInt(m.fromMove)} kcal more',
              'About ${fmtInt((stepsExtra / 100).round() * 100)} extra steps, or 🚶 ${minsFor('walk')} min walk · 🚴 ${minsFor('cycle')} min cycling · 🪢 ${minsFor('skip')} min skipping.')
        else
          _dotRow(context, p.water, 'Movement: a bonus',
              'Your food plan already covers it. Reaching your ${fmtInt(stepGoalOf(profile))} steps a day (≈ ${fmtInt(stepKcal(stepGoalOf(profile), m.cur))} kcal) gets you there faster.'),
        const SizedBox(height: 14),
        todayRow(),
        if (lose && m.needed > 1000) ...[
          const SizedBox(height: 12),
          NoteBox('⚠️', 'This pace is hard to keep up.',
              'It needs more than 1,000 kcal a day. Pick a later goal date in Profile for a safer plan.', p.chili),
        ],
      ]),
    );
  }

  Widget _dotRow(BuildContext context, Color c, String title, String sub) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5, right: 10),
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              Muted(sub),
            ]),
          ),
        ],
      );
}

class _Bar extends StatelessWidget {
  final double frac;
  final Color color;
  const _Bar({required this.frac, required this.color});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(99),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: frac),
        duration: const Duration(milliseconds: 1100),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(value: v, minHeight: 9, color: color, backgroundColor: p.steel),
      ),
    );
  }
}

// =====================================================================
// "This week" hero
// =====================================================================
class WeekHero extends StatelessWidget {
  final List<DayLog> days; // newest first
  final Profile profile;
  final List<WeightEntry> weights;
  final VoidCallback onTap;
  const WeekHero({super.key, required this.days, required this.profile, required this.weights, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final g = profile.goals;
    final ws = weekScore(days, profile);
    final loggedAll = days.where((d) => d.meals.isNotEmpty).length;
    final locked = loggedAll < 3;
    final (gName, gCol) = gradeOf(ws.score);
    final week = days.take(7).toList().reversed.toList();
    final logged = week.where((d) => d.meals.isNotEmpty).length;
    // weight change over 30 days
    final cut = dayKey(DateTime.now().subtract(const Duration(days: 30)));
    final inR = weights.where((w) => w.date.compareTo(cut) >= 0).toList();
    final before = weights.where((w) => w.date.compareTo(cut) < 0).toList();
    final base = before.isNotEmpty ? before.last : (inR.isNotEmpty ? inR.first : null);
    final last = weights.isNotEmpty ? weights.last : null;
    final wch = base != null && last != null && base != last ? last.kg - base.kg : null;
    final wGood = wch != null && (profile.goal == 'gain' ? wch > 0 : wch < 0);
    const wd = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

    Widget stat(String icon, Color c, String v, String l, {Color? vc}) => Row(children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: tint(c, 0.14, p.surface), borderRadius: BorderRadius.circular(11)),
            child: Text(icon, style: const TextStyle(fontSize: 15)),
          ),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: vc ?? p.ink)),
            Muted(l, size: 12),
          ]),
        ]);

    return Panel(
      onTap: onTap,
      gradient: LinearGradient(
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
        colors: [tint(p.leaf, 0.13, p.surface), p.surface, tint(p.saffron, 0.07, p.surface)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Eyebrow('This week'),
              H2(locked ? 'Unlock your weekly score' : (ws.hasData ? '$gName week!' : 'Start your week')),
            ]),
          ),
          Icon(Icons.chevron_right, color: p.muted),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Ring(
            value: locked ? 0.0 : ws.score / 100,
            color: gCol(p),
            size: 104,
            stroke: 9,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(locked ? '🔒' : '${ws.score}', style: display(context, 28, weight: FontWeight.w700)),
              Text('SCORE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: p.muted, letterSpacing: 1)),
            ]),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              stat('🔥', p.saffron, '${streakFrom(days)}', 'day streak'),
              const SizedBox(height: 10),
              stat('⚖️', p.leaf, wch == null ? '–' : '${wch > 0 ? '+' : ''}${kg(wch)}', 'in 30 days',
                  vc: wch == null || wch == 0 ? null : (wGood ? p.leaf : p.chili)),
              const SizedBox(height: 10),
              stat('📅', p.water, '$logged/7', 'days logged'),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < week.length; i++)
              () {
                final d = week[i];
                final has = d.meals.isNotEmpty;
                final ok = has && (d.totals.kcal - g.kcal).abs() <= g.kcal * .1;
                final isToday = i == week.length - 1;
                final c = has ? (ok ? p.leaf : p.saffron) : null;
                return Column(children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: c,
                      shape: BoxShape.circle,
                      border: c == null ? Border.all(color: p.line, width: 2) : (isToday ? Border.all(color: p.ink, width: 2) : null),
                    ),
                    child: Text(has ? (ok ? '✓' : '•') : '',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13)),
                  ),
                  const SizedBox(height: 5),
                  Text(wd[parseDay(d.date).weekday - 1],
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w800, color: isToday ? p.ink : p.muted)),
                ]);
              }(),
          ],
        ),
        const SizedBox(height: 10),
        Muted(locked
            ? 'Log ${3 - loggedAll} more day${3 - loggedAll == 1 ? '' : 's'} to unlock your report card'
            : 'Tap to see your full weekly report card'),
      ]),
    );
  }
}

// =====================================================================
// History row with a small % ring
// =====================================================================
class HistoryRow extends StatelessWidget {
  final DayLog day;
  final Goals goals;
  const HistoryRow({super.key, required this.day, required this.goals});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = day.totals, fr = t.kcal / math.max(1, goals.kcal);
    final over = t.kcal > goals.kcal * 1.1, ok = (t.kcal - goals.kcal).abs() <= goals.kcal * .1;
    final c = over ? p.chili : (ok ? p.leaf : p.saffron);
    final dt = parseDay(day.date), now = DateTime.now();
    const wd = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final isToday = day.date == dayKey(now);
    final isYest = day.date == dayKey(now.subtract(const Duration(days: 1)));
    final label = isToday ? 'Today' : (isYest ? 'Yesterday' : '${wd[dt.weekday - 1]}, ${dt.day} ${mo[dt.month - 1]}');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Ring(
          value: fr.clamp(0.0, 1.0).toDouble(),
          color: c,
          size: 42,
          stroke: 4.5,
          child: Text('${(fr * 100).round()}%', style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: tint(p.chili, .1, p.surface), borderRadius: BorderRadius.circular(99)),
                child: Text('P ${t.protein.round()} g',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: p.chili)),
              ),
              const SizedBox(width: 6),
              Muted(ok ? 'On target' : (over ? 'Over goal' : 'Under goal'), size: 12),
            ]),
          ]),
        ),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(fmtInt(t.kcal), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const Muted('kcal', size: 11),
        ]),
      ]),
    );
  }
}

/// Small segmented control: 1M / 3M / All.
class RangeTabs extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const RangeTabs({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    Widget b(String t, int v) => GestureDetector(
          onTap: () => onChanged(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: value == v ? p.surface : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
              boxShadow: value == v ? [BoxShadow(color: Colors.black.withValues(alpha: .08), blurRadius: 6)] : null,
            ),
            child: Text(t,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: value == v ? p.ink : p.muted)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [b('1M', 30), b('3M', 90), b('All', 0)]),
    );
  }
}

/// Average macro split donut with legend.
class MacroSplit extends StatelessWidget {
  final Totals avg;
  const MacroSplit({super.key, required this.avg});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final pk = avg.protein * 4, ck = avg.carbs * 4, fk = avg.fat * 9, tk = pk + ck + fk;
    int pc(double v) => tk > 0 ? (v / tk * 100).round() : 0;
    Widget leg(Color c, String n, int v) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 4),
          Text('$n $v%', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: p.muted)),
        ]);
    return Wrap(spacing: 10, runSpacing: 4, children: [
      leg(p.leaf, 'Protein', pc(pk)),
      leg(p.wheat, 'Carbs', pc(ck)),
      leg(p.chili, 'Fat', pc(fk)),
    ]);
  }
}
