import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/goals.dart';
import '../theme.dart';
import '../services/units.dart';

// ============================================================
// Rings
// ============================================================
class _RingPainter extends CustomPainter {
  final double value; // 0..1
  final Color color, track;
  final double stroke;
  final int ticks;
  final Color? tickColor;
  _RingPainter(this.value, this.color, this.track, this.stroke,
      {this.ticks = 0, this.tickColor});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        rect,
        0,
        math.pi * 2,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (ticks > 0) {
      final tp = Paint()
        ..color = tickColor ?? track
        ..strokeWidth = 1;
      final r1 = r - stroke / 2 - 4;
      for (var i = 0; i < ticks; i++) {
        final a = i / ticks * math.pi * 2;
        final r2 = r1 - (i % 5 == 0 ? 5 : 3);
        canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r1,
            c + Offset(math.cos(a), math.sin(a)) * r2, tp);
      }
    }
    final v = value.clamp(0.0, 1.0);
    if (v <= 0) return;
    canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * v,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_RingPainter o) =>
      o.value != value || o.color != color || o.track != track;
}

/// Ring that animates to [value] (0..1).
class Ring extends StatelessWidget {
  final double value, size, stroke;
  final Color color;
  final Color? track;
  final Widget? child;
  final int ticks;
  final Duration duration;
  const Ring({
    super.key,
    required this.value,
    required this.color,
    this.size = 64,
    this.stroke = 7,
    this.track,
    this.child,
    this.ticks = 0,
    this.duration = const Duration(milliseconds: 1100),
  });
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: duration,
        curve: Curves.easeOutCubic,
        builder: (_, v, ch) => CustomPaint(
          painter: _RingPainter(v, color, track ?? p.plateTrack, stroke,
              ticks: ticks, tickColor: p.muted.withValues(alpha: 0.35)),
          child: Center(child: ch),
        ),
        child: child,
      ),
    );
  }
}

/// Protein / carbs / fat ring with label underneath.
class MacroRing extends StatelessWidget {
  final String label;
  final double value;
  final int goal;
  final Color color;
  const MacroRing(
      {super.key,
      required this.label,
      required this.value,
      required this.goal,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final frac = goal <= 0 ? 0.0 : value / goal;
    return Column(children: [
      Ring(
        value: frac,
        color: color,
        size: 70,
        stroke: 7,
        child: Text('${(frac.clamp(0, 9.99) * 100).round()}%',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
      const SizedBox(height: 8),
      Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      Text('${value.round()} / $goal g',
          style: TextStyle(
              color: Palette.of(context).muted,
              fontSize: 12.5,
              fontWeight: FontWeight.w600)),
    ]);
  }
}

// ============================================================
// Macro donut (result screen)
// ============================================================
class MacroDonut extends StatelessWidget {
  final Totals t;
  final double size;
  const MacroDonut(this.t, {super.key, this.size = 118});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, k, __) => CustomPaint(
          painter: _DonutPainter(
              [t.protein * 4, t.carbs * 4, t.fat * 9], [p.leaf, p.wheat, p.chili], p.steel, k),
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${t.kcal.round()}', style: display(context, 24)),
              Text('kcal',
                  style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final List<double> vals;
  final List<Color> colors;
  final Color track;
  final double k;
  _DonutPainter(this.vals, this.colors, this.track, this.k);
  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 13.0;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.shortestSide / 2 - stroke / 2);
    canvas.drawArc(rect, 0, math.pi * 2, false,
        Paint()..color = track..style = PaintingStyle.stroke..strokeWidth = stroke);
    final all = vals.fold(0.0, (a, b) => a + b);
    if (all <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < vals.length; i++) {
      final sweep = vals[i] / all * math.pi * 2 * k;
      if (sweep > 0.04) {
        canvas.drawArc(rect, start, sweep - 0.04, false,
            Paint()..color = colors[i]..style = PaintingStyle.stroke..strokeWidth = stroke);
      }
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.k != k || o.vals != vals;
}

// ============================================================
// BMI gauge
// ============================================================
class BmiGauge extends StatelessWidget {
  final double weightKg, heightCm;
  const BmiGauge({super.key, required this.weightKg, required this.heightCm});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final b = bmi(weightKg, heightCm);
    final band = bmiBandOf(b);
    final h = heightCm / 100;
    final minW = 18.5 * h * h, maxW = (bmiHealthyMax - 0.1) * h * h;
    return Column(children: [
      AspectRatio(
        aspectRatio: 320 / 175,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 15, end: b.clamp(15.0, 35.0)),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.elasticOut,
          builder: (_, v, __) => CustomPaint(painter: _GaugePainter(v, p)),
        ),
      ),
      const SizedBox(height: 6),
      Text(b.toStringAsFixed(1), style: display(context, 34)),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
            color: band.color(p).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(99)),
        child: Text(band.name,
            style: TextStyle(color: band.color(p), fontWeight: FontWeight.w800)),
      ),
      const SizedBox(height: 12),
      Text.rich(
        TextSpan(
            text: 'Healthy weight for ${Units.height(heightCm)}: ',
            style: TextStyle(color: p.muted, fontWeight: FontWeight.w600, fontSize: 13.5),
            children: [
              TextSpan(
                  text: '${Units.toW(minW).round()}–${Units.toW(maxW).round()} ${Units.w}',
                  style: TextStyle(color: p.ink, fontWeight: FontWeight.w800)),
            ]),
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 12,
        runSpacing: 4,
        children: bmiBands
            .map((x) => Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                          color: x.color(p), borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 5),
                  Text(x.name, style: TextStyle(color: p.muted, fontSize: 12)),
                ]))
            .toList(),
      ),
      const SizedBox(height: 6),
      Text('Using $bmiRangesName.',
          style: TextStyle(color: p.muted, fontSize: 11.5)),
    ]);
  }
}

class _GaugePainter extends CustomPainter {
  final double v;
  final Palette p;
  _GaugePainter(this.v, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 320;
    canvas.scale(s);
    const cx = 160.0, cy = 160.0, r = 120.0, lo = 15.0, hi = 35.0;
    double ang(double x) => math.pi * (1 - (x - lo) / (hi - lo));
    final rect = Rect.fromCircle(center: const Offset(cx, cy), radius: r);
    var prev = lo;
    for (final b in bmiBands) {
      final end = math.min(b.max, hi);
      final a1 = ang(prev + 0.25), a2 = ang(end - 0.25);
      canvas.drawArc(
          rect,
          -a1,
          a1 - a2,
          false,
          Paint()
            ..color = b.color(p)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 22
            ..strokeCap = StrokeCap.round);
      prev = end;
    }
    for (final t in [bmiEdges[1], bmiEdges[2], bmiEdges[3]]) {
      final a = ang(t);
      final tp = TextPainter(
        text: TextSpan(
            text: t == t.roundToDouble() ? '${t.round()}' : '$t',
            style: TextStyle(color: p.muted, fontSize: 12, fontWeight: FontWeight.w700)),
        textDirection: TextDirection.ltr,
      )..layout();
      final pos = Offset(cx + 146 * math.cos(a), cy - 146 * math.sin(a));
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    }
    // needle
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-(ang(v) - math.pi / 2));
    final needle = Path()
      ..moveTo(-4, 0)
      ..lineTo(0, -92)
      ..lineTo(4, 0)
      ..close();
    canvas.drawPath(needle, Paint()..color = p.ink);
    canvas.restore();
    canvas.drawCircle(const Offset(cx, cy), 12, Paint()..color = p.ink);
    canvas.drawCircle(const Offset(cx, cy), 5, Paint()..color = p.surface);
  }

  @override
  bool shouldRepaint(_GaugePainter o) => o.v != v || o.p != p;
}

// ============================================================
// Water glass
// ============================================================
class WaterGlass extends StatelessWidget {
  final double frac;
  const WaterGlass(this.frac, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: frac.clamp(0.0, 1.0)),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (_, v, __) =>
          CustomPaint(size: const Size(46, 60), painter: _GlassPainter(v, p)),
    );
  }
}

class _GlassPainter extends CustomPainter {
  final double v;
  final Palette p;
  _GlassPainter(this.v, this.p);
  @override
  void paint(Canvas canvas, Size s) {
    final glass = Path()
      ..moveTo(3, 3)
      ..lineTo(s.width - 3, 3)
      ..lineTo(s.width - 7, s.height - 4)
      ..quadraticBezierTo(s.width - 8, s.height, s.width - 12, s.height)
      ..lineTo(12, s.height)
      ..quadraticBezierTo(8, s.height, 7, s.height - 4)
      ..close();
    canvas.save();
    canvas.clipPath(glass);
    canvas.drawRect(Offset.zero & s, Paint()..color = p.steel.withValues(alpha: 0.5));
    final top = s.height - (s.height - 6) * v.clamp(0.0, 1.0);
    canvas.drawRect(Rect.fromLTRB(0, top, s.width, s.height), Paint()..color = p.water);
    canvas.restore();
    canvas.drawPath(
        glass,
        Paint()
          ..color = p.muted.withValues(alpha: 0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_GlassPainter o) => o.v != v;
}

// ============================================================
// Charts
// ============================================================
/// Bar chart that always starts from 0, shows a number on every bar and
/// scrolls left and right when there are too many days to fit.
class BarChart extends StatelessWidget {
  final List<String> labels;
  final List<double> values;
  final double goal;
  final Color under, over;
  final int highlight; // index drawn bold (today)
  const BarChart(
      {super.key,
      required this.labels,
      required this.values,
      required this.goal,
      required this.under,
      required this.over,
      this.highlight = -1});

  static const _axisW = 36.0, _minSlot = 44.0, _height = 200.0;

  /// A round top value for the axis (e.g. 2,500 or 10,000).
  static double niceMax(double v) {
    if (v <= 0) return 1;
    final mag = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1.0, 1.5, 2.0, 2.5, 3.0, 4.0, 5.0, 6.0, 8.0, 10.0]) {
      if (m * mag >= v) return m * mag;
    }
    return 10 * mag;
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final maxVal = values.fold(0.0, math.max);
    final top = niceMax(math.max(goal, maxVal) * 1.05);
    return LayoutBuilder(builder: (context, outer) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CustomPaint(size: const Size(20, 10), painter: _DashPainter(p.ink.withValues(alpha: 0.45))),
        const SizedBox(width: 6),
        Text('Goal ${fmtInt(goal)}',
            style: TextStyle(fontSize: 12, color: p.muted, fontWeight: FontWeight.w800)),
        const Spacer(),
        if (values.length * _minSlot > outer.maxWidth - _axisW)
          Row(children: [
            Icon(Icons.swipe, size: 15, color: p.muted),
            const SizedBox(width: 4),
            Text('Swipe', style: TextStyle(fontSize: 11.5, color: p.muted, fontWeight: FontWeight.w700)),
          ]),
      ]),
      const SizedBox(height: 6),
      SizedBox(
        height: _height,
        child: LayoutBuilder(builder: (context, box) {
          final avail = box.maxWidth - _axisW;
          final scroll = values.length * _minSlot > avail;
          final w = scroll ? values.length * _minSlot : avail;
          final chart = TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOutCubic,
            builder: (_, k, __) => CustomPaint(
              size: Size(w, _height),
              painter: _BarPainter(labels, values, goal, top, under, over, highlight, k, p),
            ),
          );
          return Row(children: [
            SizedBox(
              width: _axisW,
              height: _height,
              child: CustomPaint(painter: _AxisPainter(top, p)),
            ),
            Expanded(
              child: scroll
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      reverse: true, // opens on today; swipe right for older days
                      physics: const BouncingScrollPhysics(),
                      child: SizedBox(width: w, height: _height, child: chart),
                    )
                  : chart,
            ),
          ]);
        }),
      ),
    ]));
  }
}

// shared layout for the axis and the bars
const _barTop = 22.0, _barBottom = 26.0;

class _DashPainter extends CustomPainter {
  final Color c;
  _DashPainter(this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final pt = Paint()
      ..color = c
      ..strokeWidth = 1.6;
    for (double x = 0; x < size.width; x += 7) {
      canvas.drawLine(Offset(x, size.height / 2), Offset(math.min(x + 4, size.width), size.height / 2), pt);
    }
  }

  @override
  bool shouldRepaint(_DashPainter o) => o.c != c;
}

String _short(double v) {
  if (v >= 10000) return '${(v / 1000).toStringAsFixed(v >= 100000 ? 0 : 1).replaceAll('.0', '')}k';
  return fmtInt(v);
}

class _AxisPainter extends CustomPainter {
  final double top;
  final Palette p;
  _AxisPainter(this.top, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height - _barTop - _barBottom;
    for (final f in [0.0, 0.5, 1.0]) {
      final v = top * f;
      final y = _barTop + (1 - f) * h;
      final tp = TextPainter(
          text: TextSpan(
              text: v >= 1000 ? '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k' : v.round().toString(),
              style: TextStyle(fontSize: 10.5, color: p.muted, fontWeight: FontWeight.w600)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(size.width - 6 - tp.width, y - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_AxisPainter o) => o.top != top;
}

class _BarPainter extends CustomPainter {
  final List<String> labels;
  final List<double> values;
  final double goal, top, k;
  final Color under, over;
  final int highlight;
  final Palette p;
  _BarPainter(this.labels, this.values, this.goal, this.top, this.under, this.over,
      this.highlight, this.k, this.p);

  void _text(Canvas c, String t, Offset at, double size, Color col,
      {FontWeight w = FontWeight.w600}) {
    final tp = TextPainter(
        text: TextSpan(text: t, style: TextStyle(fontSize: size, color: col, fontWeight: w)),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c, at - Offset(tp.width / 2, tp.height));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final n = values.length;
    if (n == 0) return;
    final h = size.height - _barTop - _barBottom;
    double y(double v) => _barTop + (1 - v / top) * h;
    final gap = size.width / n, bw = math.min(26.0, gap * 0.56);
    // light grid lines at 0, half and top
    final grid = Paint()
      ..color = p.line
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final gy = _barTop + (1 - f) * h;
      canvas.drawLine(Offset(0, gy), Offset(size.width, gy), grid);
    }
    // bars
    for (var i = 0; i < n; i++) {
      final v = values[i] * k;
      final cx = gap * i + gap / 2;
      if (values[i] <= 0) continue;
      final bh = math.max(4.0, (_barTop + h) - y(v));
      final col = values[i] > goal ? over : under;
      final r = Rect.fromLTWH(cx - bw / 2, _barTop + h - bh, bw, bh);
      canvas.drawRRect(
          RRect.fromRectAndCorners(r,
              topLeft: Radius.circular(math.min(8, bw / 2)), topRight: Radius.circular(math.min(8, bw / 2))),
          Paint()
            ..shader = LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [col, col.withValues(alpha: i == highlight ? 0.75 : 0.5)])
                .createShader(r));
    }
    // goal line
    final gy = y(goal);
    final dash = Paint()
      ..color = p.ink.withValues(alpha: 0.45)
      ..strokeWidth = 1.4;
    for (double x = 0; x < size.width; x += 8) {
      canvas.drawLine(Offset(x, gy), Offset(math.min(x + 4, size.width), gy), dash);
    }
    // a number on every bar
    if (k > 0.6) {
      final fs = gap >= 40 ? 10.5 : 9.5;
      for (var i = 0; i < n; i++) {
        if (values[i] <= 0) continue;
        final cx = gap * i + gap / 2;
        final ty = math.max(_barTop - 2, y(values[i] * k) - 4);
        final txt = gap >= 40 ? fmtInt(values[i]) : _short(values[i]);
        _text(canvas, txt, Offset(cx, ty), fs, i == highlight ? p.ink : p.ink.withValues(alpha: 0.75),
            w: i == highlight ? FontWeight.w900 : FontWeight.w700);
      }
    }
    // day labels
    for (var i = 0; i < n; i++) {
      final cx = gap * i + gap / 2;
      final lbl = i == highlight ? 'Today' : labels[i];
      if (lbl.isEmpty) continue;
      _text(canvas, lbl, Offset(cx, size.height - 6), 11.5, i == highlight ? p.ink : p.muted,
          w: i == highlight ? FontWeight.w800 : FontWeight.w600);
    }
  }

  @override
  bool shouldRepaint(_BarPainter o) => o.k != k || o.values != values || o.top != top;
}

class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double? target;
  const WeightChart({super.key, required this.entries, this.target});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return SizedBox(
      height: 170,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1300),
        curve: Curves.easeOutCubic,
        builder: (_, k, __) =>
            CustomPaint(size: Size.infinite, painter: _LinePainter(entries, target, k, p)),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<WeightEntry> e;
  final double? target;
  final double k;
  final Palette p;
  _LinePainter(this.e, this.target, this.k, this.p);
  @override
  void paint(Canvas canvas, Size size) {
    const l = 34.0, r = 10.0, t = 14.0, b = 24.0;
    final days = e.map((x) => DateTime.parse(x.date)).toList();
    final t0 = days.first.millisecondsSinceEpoch.toDouble();
    final t1 = math.max(t0 + 1, days.last.millisecondsSinceEpoch.toDouble());
    final ys = [...e.map((x) => x.kg), if (target != null) target!];
    final lo = (ys.reduce(math.min) - 1).floorToDouble();
    final hi = (ys.reduce(math.max) + 1).ceilToDouble();
    double x(int i) => l + (days[i].millisecondsSinceEpoch - t0) / (t1 - t0) * (size.width - l - r);
    double y(double v) => t + (hi - v) / (hi - lo) * (size.height - t - b);
    final grid = Paint()..color = p.line;
    for (final v in [lo, (lo + hi) / 2, hi]) {
      canvas.drawLine(Offset(l, y(v)), Offset(size.width - r, y(v)), grid);
      final tp = TextPainter(
          text: TextSpan(text: v.toStringAsFixed(0), style: TextStyle(fontSize: 11, color: p.muted)),
          textDirection: TextDirection.ltr)
        ..layout();
      tp.paint(canvas, Offset(l - 6 - tp.width, y(v) - tp.height / 2));
    }
    if (target != null) {
      final ty = y(target!);
      final d = Paint()..color = p.leaf..strokeWidth = 1.2;
      for (double xx = l; xx < size.width - r; xx += 8) {
        canvas.drawLine(Offset(xx, ty), Offset(math.min(xx + 4, size.width - r), ty), d);
      }
    }
    final path = Path()..moveTo(x(0), y(e[0].kg));
    for (var i = 1; i < e.length; i++) {
      final cx = (x(i - 1) + x(i)) / 2;
      path.cubicTo(cx, y(e[i - 1].kg), cx, y(e[i].kg), x(i), y(e[i].kg));
    }
    // area
    final area = Path.from(path)
      ..lineTo(x(e.length - 1), size.height - b)
      ..lineTo(x(0), size.height - b)
      ..close();
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, l + (size.width - l) * k, size.height));
    canvas.drawPath(
        area,
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, t), Offset(0, size.height - b),
              [p.saffron.withValues(alpha: 0.28), p.saffron.withValues(alpha: 0)]));
    canvas.drawPath(
        path,
        Paint()
          ..color = p.saffron
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round);
    canvas.restore();
    if (k > 0.98) {
      final lp = Offset(x(e.length - 1), y(e.last.kg));
      canvas.drawCircle(lp, 6, Paint()..color = p.surface);
      canvas.drawCircle(lp, 6, Paint()..color = p.saffron..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }

  @override
  bool shouldRepaint(_LinePainter o) => o.k != k || o.e != e;
}

// ============================================================
// Skeleton shimmer
// ============================================================
class Shimmer extends StatefulWidget {
  final double width, height, radius;
  const Shimmer({super.key, this.width = double.infinity, this.height = 12, this.radius = 10});
  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1150))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(-1 + _c.value * 3 - 1, 0),
            end: Alignment(_c.value * 3 - 1, 0),
            colors: [p.steel.withValues(alpha: .7), Color.lerp(p.steel, p.surface, .55)!, p.steel.withValues(alpha: .7)],
          ),
        ),
      ),
    );
  }
}

/// Three bouncing dots.
class Dots extends StatefulWidget {
  final Color color;
  const Dots({super.key, required this.color});
  @override
  State<Dots> createState() => _DotsState();
}

class _DotsState extends State<Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = ((_c.value - i * 0.15) % 1.0);
            final up = t < 0.4 ? math.sin(t / 0.4 * math.pi) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, -6 * up),
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: widget.color.withValues(alpha: 0.4 + 0.6 * up), shape: BoxShape.circle),
                ),
              ),
            );
          }),
        ),
      );
}
