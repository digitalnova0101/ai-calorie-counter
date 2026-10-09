// Extra pieces for the setup flow: goal tip, pace picker, multi-select chips
// and the "Your goal" card with its chart (same design as the website).
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/goals.dart';
import '../services/health_data.dart';
import '../theme.dart';
import '../widgets/premium.dart';
import '../widgets/ui.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
String niceDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

DateTime _today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime dateForPace(double weight, double target, double pace) {
  final weeks = math.max(2, ((weight - target).abs() / math.max(0.05, pace)).ceil());
  return _today().add(Duration(days: weeks * 7));
}

double paceOf(double weight, double target, DateTime? date) {
  if (date == null) return 0.5;
  final days = math.max(1, date.difference(_today()).inDays);
  return (weight - target).abs() / (days / 7);
}

class TargetTip {
  final String head, sub, body;
  final Color Function(Palette) color;
  const TargetTip(this.head, this.sub, this.body, this.color);
}

TargetTip targetTip(String goal, double w, double t, double heightCm) {
  final h = heightCm / 100, tb = t / (h * h);
  final pct = w > 0 ? (w - t).abs() / w * 100 : 0;
  final bmiTxt = 'Target BMI ${tb.toStringAsFixed(1)}';
  if (goal == 'lose') {
    if (t >= w) return TargetTip("Pick a weight below today's", '', 'Lower the number to set your goal.', (p) => p.danger);
    if (tb < 18.5) {
      return TargetTip('Lose ${pct.round()}%', bmiTxt, 'This is below the healthy BMI range. Consider a higher goal weight.', (p) => p.chili);
    }
    if (pct <= 10) {
      return TargetTip('Good for health: lose ${pct.round()}%', bmiTxt,
          'Losing 5% to 10% of body weight helps blood sugar, blood pressure and energy.', (p) => p.leaf);
    }
    if (pct <= 20) {
      return TargetTip('Ambitious: lose ${pct.round()}%', bmiTxt, 'A bigger goal. Reaching it in 5% steps keeps it realistic.', (p) => p.wheat);
    }
    return TargetTip('Very ambitious: lose ${pct.round()}%', bmiTxt,
        'Big changes take time. Talk to a doctor if you plan to lose this much.', (p) => p.chili);
  }
  if (t <= w) return TargetTip("Pick a weight above today's", '', 'Raise the number to set your goal.', (p) => p.danger);
  if (tb > 25) {
    return TargetTip('Gain ${pct.round()}%', bmiTxt, 'This goes above the healthy BMI range. A smaller gain may suit you better.', (p) => p.chili);
  }
  return TargetTip('Gain ${pct.round()}% lean weight', bmiTxt, 'Pair this with strength training and enough protein.', (p) => p.leaf);
}

class TargetTipBox extends StatelessWidget {
  final TargetTip tip;
  const TargetTipBox({super.key, required this.tip});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context), c = tip.color(p);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: tint(c, .1, p.surface),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint(c, .35, p.line)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(tip.head, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: c))),
          if (tip.sub.isNotEmpty) Pill(tip.sub, c),
        ]),
        const SizedBox(height: 6),
        Text(tip.body, style: TextStyle(color: p.ink, height: 1.45)),
      ]),
    );
  }
}

/// Pace options (kg per week) that set the goal date, or pick a date yourself.
class PacePicker extends StatelessWidget {
  final bool lose;
  final double weight, target;
  final DateTime? date;
  final ValueChanged<DateTime> onDate;
  const PacePicker(
      {super.key, required this.lose, required this.weight, required this.target, required this.date, required this.onDate});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final opts = lose
        ? const [(0.25, '🐢', 'Slow and easy'), (0.5, '⭐', 'Recommended'), (0.75, '🏃', 'Faster'), (1.0, '🔥', 'Fastest safe pace')]
        : const [(0.25, '🌱', 'Lean and steady'), (0.35, '⭐', 'Recommended'), (0.5, '💪', 'Faster')];
    final cur = date ?? dateForPace(weight, target, lose ? 0.5 : 0.35);
    final pace = paceOf(weight, target, cur);
    final days = math.max(1, cur.difference(_today()).inDays);
    final safe = lose ? pace <= 1.0 : pace <= 0.5;
    final diff = (weight - target).abs();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (final (v, e, l) in opts)
        () {
          final d = dateForPace(weight, target, v);
          final on = (pace - v).abs() < 0.02 || (date != null && dayKeyLocal(date!) == dayKeyLocal(d));
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Pressable(
              onTap: () => onDate(d),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: on ? tint(p.leaf, .09, p.surface) : p.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: on ? p.leaf : p.line, width: 1.5),
                ),
                child: Row(children: [
                  Text(e, style: const TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$l · ${v.toStringAsFixed(2)} kg / week',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                      Muted('Reach ${target.toStringAsFixed(1)} kg by ${niceDate(d)}'),
                    ]),
                  ),
                  if (on) Icon(Icons.check_circle, color: p.leaf),
                ]),
              ),
            ),
          );
        }(),
      OutlinedButton.icon(
        onPressed: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: cur,
            firstDate: _today().add(const Duration(days: 7)),
            lastDate: _today().add(const Duration(days: 730)),
            helpText: 'Pick your goal date',
          );
          if (picked != null) onDate(picked);
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: const Text('Pick my own date'),
      ),
      const SizedBox(height: 14),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: tint(safe ? p.leaf : p.chili, .1, p.surface),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(text: safe ? '✓ Safe pace. ' : '⚠ Too fast. ', style: const TextStyle(fontWeight: FontWeight.w800)),
            TextSpan(
                text: 'I want to ${lose ? 'lose' : 'gain'} ${diff.toStringAsFixed(1)} kg in $days days, averaging '
                    '${pace.toStringAsFixed(2)} kg per week.'),
          ]),
          style: TextStyle(color: safe ? p.ink : p.chili, height: 1.45),
        ),
      ),
    ]);
  }
}

String dayKeyLocal(DateTime d) => '${d.year}-${d.month}-${d.day}';

/// Multi-select list of choices; "none" clears the others.
class MultiChoice extends StatelessWidget {
  final List<Choice> choices;
  final Set<String> selected;
  final VoidCallback onChanged;
  const MultiChoice({super.key, required this.choices, required this.selected, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Wrap(spacing: 10, runSpacing: 10, children: [
      for (final c in choices)
        () {
          final on = selected.contains(c.id) || (c.id == 'none' && selected.isEmpty);
          return Pressable(
            onTap: () {
              if (c.id == 'none') {
                selected.clear();
              } else if (!selected.remove(c.id)) {
                selected
                  ..remove('none')
                  ..add(c.id);
              }
              onChanged();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: on ? tint(p.leaf, .1, p.surface) : p.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: on ? p.leaf : p.line, width: 1.5),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(c.emoji, style: const TextStyle(fontSize: 17)),
                const SizedBox(width: 8),
                Text(c.label, style: const TextStyle(fontWeight: FontWeight.w700)),
                if (on) ...[const SizedBox(width: 6), Icon(Icons.check, size: 16, color: p.leaf)],
              ]),
            ),
          );
        }(),
    ]);
  }
}

/// "Your goal" card on the plan screen: big number, safe-pace chip, chart, 3 stats.
class PlanGoalCard extends StatelessWidget {
  final bool lose;
  final double weight, target, heightCm;
  final DateTime date;
  const PlanGoalCard(
      {super.key, required this.lose, required this.weight, required this.target, required this.heightCm, required this.date});

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final diff = (weight - target).abs();
    final days = math.max(1, date.difference(_today()).inDays);
    final weeks = days / 7, pace = diff / weeks;
    final safe = lose ? pace <= 1 : pace <= 0.5;
    final h = heightCm / 100, tb = target / (h * h);
    return Panel(
      gradient: LinearGradient(
          begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [tint(p.leaf, .1, p.surface), p.surface]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Expanded(child: Eyebrow('Your goal')),
          Pill(safe ? '✓ Safe pace' : '⚠ Fast pace', safe ? p.leaf : p.chili),
        ]),
        const SizedBox(height: 6),
        Text('${lose ? '−' : '+'}${diff.toStringAsFixed(1)} kg', style: display(context, 34, weight: FontWeight.w700)),
        const SizedBox(height: 2),
        Muted('to ${lose ? 'lose' : 'gain'} by ${niceDate(date)}'),
        const SizedBox(height: 12),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 1600),
          curve: Curves.easeOutCubic,
          builder: (context, k, _) => CustomPaint(
            size: const Size(double.infinity, 190),
            painter: _PlanChartPainter(p: p, from: weight, to: target, start: _today(), end: date, k: k),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: StatTile('Weekly pace', '${pace.toStringAsFixed(2)} kg')),
          const SizedBox(width: 8),
          Expanded(child: StatTile('Time', weeks >= 8 ? '${(weeks / 4.35).round()} months' : '${weeks.round()} weeks')),
          const SizedBox(width: 8),
          Expanded(child: StatTile('Goal BMI', tb.toStringAsFixed(1))),
        ]),
      ]),
    );
  }
}

class _PlanChartPainter extends CustomPainter {
  final Palette p;
  final double from, to, k;
  final DateTime start, end;
  _PlanChartPainter({required this.p, required this.from, required this.to, required this.start, required this.end, required this.k});

  void _text(Canvas c, String t, Offset at, {double size = 11, Color? color, FontWeight w = FontWeight.w700, bool center = false, bool right = false}) {
    final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: size, color: color ?? p.muted, fontWeight: w)),
        textDirection: TextDirection.ltr)
      ..layout();
    final dx = center ? tp.width / 2 : (right ? tp.width : 0.0);
    tp.paint(c, at - Offset(dx, 0));
  }

  void _pill(Canvas c, String t, Offset center, Color bg, Color fg) {
    final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: 12, color: fg, fontWeight: FontWeight.w800)),
        textDirection: TextDirection.ltr)
      ..layout();
    final r = RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: tp.width + 20, height: 24), const Radius.circular(12));
    c.drawRRect(r, Paint()..color = bg);
    tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, x0 = 14.0, x1 = w - 14, yTop = 44.0, yBot = 140.0, base = 156.0;
    final lose = to < from;
    double y(double v) => lose ? yTop + (from - v) / (from - to) * (yBot - yTop) : yBot - (v - from) / (to - from) * (yBot - yTop);
    double ease(double t) => 1 - math.pow(1 - t, 2.1).toDouble();
    final pts = [for (var i = 0; i <= 40; i++) Offset(x0 + (x1 - x0) * i / 40, y(from + (to - from) * ease(i / 40)))];
    final n = math.max(1, (40 * k).round());
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (var i = 1; i <= n; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    final c1 = lose ? p.saffron : p.water, c2 = p.leaf;
    // month guides
    final span = end.difference(start).inDays.clamp(1, 100000);
    var m = DateTime(start.year, start.month + 1, 1);
    while (m.isBefore(end)) {
      final mx = x0 + (x1 - x0) * m.difference(start).inDays / span;
      if (mx > x0 + 64 && mx < x1 - 74) {
        canvas.drawLine(Offset(mx, yTop - 10), Offset(mx, base), Paint()..color = p.line..strokeWidth = 1);
        _text(canvas, _months[m.month - 1], Offset(mx, size.height - 18), center: true);
      }
      m = DateTime(m.year, m.month + 1, 1);
    }
    // goal line
    final gy = pts.last.dy;
    for (double x = x0; x < x1; x += 9) {
      canvas.drawLine(Offset(x, gy), Offset(math.min(x + 4, x1), gy), Paint()..color = c2.withValues(alpha: .55)..strokeWidth = 1.5);
    }
    // area
    final area = Path.from(path)
      ..lineTo(pts[n].dx, base)
      ..lineTo(pts[0].dx, base)
      ..close();
    canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [c2.withValues(alpha: .22 * k), c2.withValues(alpha: 0)])
              .createShader(Rect.fromLTRB(0, yTop, w, base)));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round
          ..shader = LinearGradient(colors: [c1, c2]).createShader(Rect.fromLTRB(x0, 0, x1, 1)));
    // start dot + pill
    canvas.drawCircle(pts[0], 6.5, Paint()..color = p.surface);
    canvas.drawCircle(pts[0], 6.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..color = c1);
    _pill(canvas, '${from.toStringAsFixed(1)} kg', Offset(pts[0].dx + 30, lose ? pts[0].dy - 24 : pts[0].dy + 24), p.ink, p.surface);
    if (k > .95) {
      final e = pts.last;
      canvas.drawCircle(e, 8, Paint()..color = c2);
      canvas.drawCircle(e, 8, Paint()..style = PaintingStyle.stroke..strokeWidth = 3.5..color = p.surface);
      _pill(canvas, '🎯 ${to.toStringAsFixed(1)} kg', Offset(e.dx - 44, gy - 28 < 2 ? gy + 26 : gy - 28), c2, Colors.white);
    }
    _text(canvas, 'Today', Offset(x0, size.height - 18), color: p.ink, w: FontWeight.w800);
    _text(canvas, '${end.day} ${_months[end.month - 1]}', Offset(x1, size.height - 18), color: p.ink, w: FontWeight.w800, right: true);
  }

  @override
  bool shouldRepaint(_PlanChartPainter o) => o.k != k || o.from != from || o.to != to || o.end != end;
}
