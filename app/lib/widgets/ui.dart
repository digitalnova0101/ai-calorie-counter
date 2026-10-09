import 'package:flutter/material.dart';

import '../theme.dart';

/// White rounded card with a hairline border.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final double radius;

  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.gradient,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? p.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: p.line),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return Pressable(onTap: onTap!, child: box);
  }
}

/// Shrinks slightly while pressed.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const Pressable({super.key, required this.child, required this.onTap});
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      );
}

class H2 extends StatelessWidget {
  final String text;
  const H2(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(text,
      style: Theme.of(context)
          .textTheme
          .titleMedium
          ?.copyWith(fontWeight: FontWeight.w800));
}

class Muted extends StatelessWidget {
  final String text;
  final double size;
  final TextAlign? align;
  const Muted(this.text, {super.key, this.size = 13, this.align});
  @override
  Widget build(BuildContext context) => Text(text,
      textAlign: align,
      style: TextStyle(
          color: Palette.of(context).muted,
          fontSize: size,
          fontWeight: FontWeight.w600));
}

/// Small dark rounded button (Start, + Workout, End...).
class PillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const PillButton(this.label, {super.key, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
            color: p.forest, borderRadius: BorderRadius.circular(12)),
        child: Text(label,
            style: TextStyle(
                color: p.forestInk, fontWeight: FontWeight.w800, fontSize: 14)),
      ),
    );
  }
}

/// Coloured nutrition chip, e.g. "240 kcal".
class MacroChip extends StatelessWidget {
  final String text;
  final Color color;
  const MacroChip(this.text, this.color, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(99),
        ),
        child: Text(text,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w800, fontSize: 12.5)),
      );
}

/// Square icon button with a border.
class SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color? fill, iconColor;
  final double size;
  const SquareIconButton(this.icon,
      {super.key,
      required this.onTap,
      required this.tooltip,
      this.fill,
      this.iconColor,
      this.size = 44});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return Tooltip(
      message: tooltip,
      child: Opacity(
        opacity: onTap == null ? 0.35 : 1,
        child: Pressable(
          onTap: onTap ?? () {},
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: fill ?? p.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: fill ?? p.line),
            ),
            child: Icon(icon, size: 22, color: iconColor ?? p.ink),
          ),
        ),
      ),
    );
  }
}

/// − [number field] + used for minutes, steps, portions.
class NumberStepper extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onMinus, onPlus;
  final ValueChanged<String> onChanged;
  final String? suffix, hint;
  final bool decimal;
  const NumberStepper({
    super.key,
    required this.controller,
    required this.onMinus,
    required this.onPlus,
    required this.onChanged,
    this.suffix,
    this.hint,
    this.decimal = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
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
              child: Text(t,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            ),
          ),
        );
    return Row(children: [
      btn('−', onMinus, 'Less'),
      const SizedBox(width: 10),
      Expanded(
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          onTap: () => controller.selection = TextSelection(
              baseOffset: 0, extentOffset: controller.text.length),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.numberWithOptions(decimal: decimal),
          style: display(context, 22, weight: FontWeight.w700),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: p.muted, fontSize: 15),
            suffixText: suffix,
            suffixStyle: TextStyle(color: p.muted, fontWeight: FontWeight.w800),
          ),
        ),
      ),
      const SizedBox(width: 10),
      btn('+', onPlus, 'More'),
    ]);
  }
}

/// Chips like "10 min", "30 min".
class QuickChips<T> extends StatelessWidget {
  final List<T> values;
  final T? selected;
  final String Function(T) label;
  final ValueChanged<T> onTap;
  final Color? accent;
  const QuickChips(
      {super.key,
      required this.values,
      required this.selected,
      required this.label,
      required this.onTap,
      this.accent});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context), a = accent ?? p.chili;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values.map((v) {
        final on = v == selected;
        return Pressable(
          onTap: () => onTap(v),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: on ? a.withValues(alpha: 0.12) : p.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: on ? a : p.line, width: 1.5),
            ),
            child: Text(label(v),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          ),
        );
      }).toList(),
    );
  }
}

/// Opens a bottom sheet in the app style.
Future<T?> showAppSheet<T>(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: builder(ctx),
      ),
    );

void toast(BuildContext context, String text,
    {String? action, VoidCallback? onAction}) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(
    content: Text(text),
    duration: Duration(milliseconds: action == null ? 2200 : 4500),
    action: action == null
        ? null
        : SnackBarAction(label: action, onPressed: onAction ?? () {}),
  ));
}

/// Counts up to [value] whenever it changes.
class CountUp extends StatelessWidget {
  final double value;
  final TextStyle style;
  final String Function(double)? format;
  const CountUp(this.value, {super.key, required this.style, this.format});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: value),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) =>
            Text(format != null ? format!(v) : v.round().toString(), style: style),
      );
}
