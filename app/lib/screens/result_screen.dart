import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models.dart';
import '../services/ai.dart';
import '../services/db.dart';
import '../services/health_data.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/ui.dart';
import 'portion_picker.dart';

/// Shows food items (AI, barcode, search, recent or an existing meal),
/// lets the user fix portions, pick the meal and save.
class ResultScreen extends StatefulWidget {
  final DateTime date;
  final String source;
  final Uint8List? image;
  final Future<String?>? thumbFuture;
  final String? thumb;
  final Future<AiResult> Function()? loader;
  final List<FoodItem>? items;
  final String dish;
  final MealEntry? editing;

  const ResultScreen({
    super.key,
    required this.date,
    required this.source,
    this.image,
    this.thumbFuture,
    this.thumb,
    this.loader,
    this.items,
    this.dish = '',
    this.editing,
  }) : assert(loader != null || items != null);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  List<FoodItem> _items = [];
  late String _dish = widget.dish;
  String _note = '';
  String? _error;
  bool _loading = false, _saving = false;
  late String _type = widget.editing?.type ?? guessMealType();
  String? _thumb;
  int _msg = 0;
  Timer? _msgTimer;
  static const _msgs = ['Finding each food…', 'Checking portion sizes…', 'Counting calories…'];

  Uint8List? get _photo =>
      widget.image ?? (widget.thumb != null ? base64Decode(widget.thumb!) : null);

  @override
  void initState() {
    super.initState();
    _thumb = widget.thumb;
    widget.thumbFuture?.then((t) => _thumb = t);
    if (widget.items != null) {
      _items = widget.items!.map((e) => e.copy()).toList();
    } else {
      _run();
    }
  }

  @override
  void dispose() {
    _msgTimer?.cancel();
    super.dispose();
  }

  Future<void> _run() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    _msgTimer?.cancel();
    _msgTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
      if (mounted) setState(() => _msg = (_msg + 1) % _msgs.length);
    });
    try {
      final r = await widget.loader!();
      if (!mounted) return;
      setState(() {
        _items = r.items;
        _dish = r.dish;
        _note = r.note;
        _loading = false;
        if (r.items.isEmpty) {
          _error = r.note.isNotEmpty ? r.note : 'No food found. Try a clear photo taken from above.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is AiException ? e.message : 'Something went wrong. Try again.';
      });
    } finally {
      _msgTimer?.cancel();
    }
  }

  void _step(FoodItem it, double d) => setState(() {
        it.mult = (((it.mult + d) * 2).round() / 2).clamp(0.5, 10.0);
        it.portionLabel = null;
      });

  Future<void> _pickPortion(FoodItem it) async {
    final changed = await showPortionPicker(context, it);
    if (changed == true && mounted) setState(() {});
  }

  Future<void> _save() async {
    if (_items.isEmpty) return;
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final key = dayKey(widget.date);
    try {
      if (widget.editing != null) {
        final e = widget.editing!;
        await Db.instance.updateMeal(
            key,
            MealEntry(
                id: e.id,
                type: _type,
                time: e.time,
                source: e.source,
                items: _items,
                dish: _dish,
                thumb: e.thumb));
        nav.popUntil((r) => r.isFirst);
        messenger.showSnackBar(const SnackBar(content: Text('Meal updated')));
      } else {
        await Db.instance.addMeal(
            key,
            MealEntry(
              id: newId('m'),
              type: _type,
              time: DateTime.now().millisecondsSinceEpoch,
              source: widget.source,
              items: _items,
              dish: _dish,
              thumb: _thumb,
            ));
        nav.popUntil((r) => r.isFirst);
        messenger.showSnackBar(SnackBar(content: Text('Added to $_type')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      toast(context, 'Could not save: $e');
    }
  }

  // ---------------- UI ----------------
  Widget _photoView(Palette p) {
    final bytes = _photo;
    if (bytes == null) return const SizedBox.shrink();
    final h = MediaQuery.of(context).size.height;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      height: _loading ? (h * 0.6).clamp(260.0, 520.0) : (h * 0.36).clamp(200.0, 320.0),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), color: const Color(0xFF101512)),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        // blurred copy fills the frame so any photo shape looks good
        ImageFiltered(
          imageFilter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Opacity(opacity: 0.75, child: Image.memory(bytes, fit: BoxFit.cover)),
        ),
        Image.memory(bytes, fit: BoxFit.contain),
        if (_loading) ...[
          const _ScanCorners(),
          const _ScanLine(),
          Positioned(
            left: 0,
            right: 0,
            bottom: 18,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                    color: const Color(0xB80C1410), borderRadius: BorderRadius.circular(99)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Dots(color: Color(0xFFFFB35C)),
                  const SizedBox(width: 10),
                  Text(_msgs[_msg],
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final t = Totals.of(_items);
    final children = <Widget>[_photoView(p)];

    if (_loading && _photo == null) {
      children.add(Panel(
        child: Column(children: [
          const SizedBox(height: 20),
          Dots(color: p.saffron),
          const SizedBox(height: 14),
          Text('Reading what you ate…', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
        ]),
      ));
    } else if (_error != null && _items.isEmpty) {
      children.add(Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_error!, style: TextStyle(color: p.danger, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          if (widget.loader != null) FilledButton(onPressed: _run, child: const Text('Try again')),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ]),
      ));
    } else if (!_loading) {
      children.addAll([
        Panel(
          child: Row(children: [
            MacroDonut(t),
            const SizedBox(width: 18),
            Expanded(
              child: Column(children: [
                _macroRow('Protein', t.protein, p.leaf),
                const SizedBox(height: 8),
                _macroRow('Carbs', t.carbs, p.wheat),
                const SizedBox(height: 8),
                _macroRow('Fat', t.fat, p.chili),
              ]),
            ),
          ]),
        ),
        Panel(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Column(children: [
            for (var i = 0; i < _items.length; i++) _StaggerIn(index: i, child: _itemRow(_items[i], i > 0, p)),
            if (_items.isEmpty)
              const Padding(padding: EdgeInsets.all(16), child: Muted('All items removed.')),
          ]),
        ),
        if (_note.isNotEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Muted(_note)),
        _MealTypePicker(value: _type, onChanged: (v) => setState(() => _type = v)),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
            onPressed: _saving || _items.isEmpty ? null : _save,
            child: Text(widget.editing != null
                ? 'Save changes'
                : 'Add to $_type${dayKey(widget.date) != dayKey(DateTime.now()) ? ', ${DateFormatShort.of(widget.date)}' : ''}'),
          ),
        ),
        const Muted('Tap a portion to pick katori, plate or glass. AI numbers can be about 20% off.',
            size: 12, align: TextAlign.center),
      ]);
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_dish.isNotEmpty ? _dish : (_loading ? 'Scanning' : 'Your meal')),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        itemCount: children.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => children[i],
      ),
    );
  }

  Widget _macroRow(String label, double g, Color c) => Row(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text('${g.round()} g', style: const TextStyle(fontWeight: FontWeight.w800)),
      ]);

  Widget _itemRow(FoodItem it, bool divider, Palette p) {
    final g = it.grams > 0 ? '${(it.grams * it.mult).round()} g' : '';
    final portion = it.portionLabel ??
        [if (it.mult == 1) it.portion else '${_fmt(it.mult)} × ${it.portion.isEmpty ? 'serving' : it.portion}', if (g.isNotEmpty && !RegExp(r'\d+\s*g\b').hasMatch(it.portion)) g]
            .where((x) => x.isNotEmpty)
            .join(', ');
    return Container(
      decoration: BoxDecoration(border: divider ? Border(top: BorderSide(color: p.line)) : null),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                Text(it.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15.5)),
                if (it.src == 'db')
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check, size: 13, color: p.leaf),
                    Text('Verified', style: TextStyle(color: p.leaf, fontWeight: FontWeight.w800, fontSize: 11.5)),
                  ]),
              ]),
              for (final al in allergensIn(it.name, Db.instance.current?.allergies ?? const []))
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: p.chili.withValues(alpha: .12), borderRadius: BorderRadius.circular(99)),
                  child: Text('⚠ May contain ${al.toLowerCase()}',
                      style: TextStyle(color: p.chili, fontWeight: FontWeight.w800, fontSize: 11.5)),
                ),
              const SizedBox(height: 4),
              Pressable(
                onTap: () => _pickPortion(it),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: p.bg,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: p.line)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Flexible(
                      child: Text(portion.isEmpty ? '1 serving' : portion,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.muted, fontWeight: FontWeight.w700, fontSize: 12.5)),
                    ),
                    Icon(Icons.expand_more, size: 16, color: p.muted),
                  ]),
                ),
              ),
            ]),
          ),
          Container(
            decoration: BoxDecoration(color: p.bg, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'Less', onPressed: () => _step(it, -0.5), icon: const Icon(Icons.remove, size: 18)),
              Text('×${_fmt(it.mult)}', style: const TextStyle(fontWeight: FontWeight.w800)),
              IconButton(visualDensity: VisualDensity.compact, tooltip: 'More', onPressed: () => _step(it, 0.5), icon: const Icon(Icons.add, size: 18)),
            ]),
          ),
          IconButton(
              tooltip: 'Remove ${it.name}',
              onPressed: () => setState(() => _items.remove(it)),
              icon: Icon(Icons.close, color: p.muted)),
        ]),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          MacroChip('${it.tKcal.round()} kcal', p.saffron),
          MacroChip('P ${it.tProtein.round()}g', p.leaf),
          MacroChip('C ${it.tCarbs.round()}g', p.wheat),
          MacroChip('F ${it.tFat.round()}g', p.chili),
        ]),
      ]),
    );
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}

/// "7 Oct" style label.
class DateFormatShort {
  static const _m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String of(DateTime d) => '${d.day} ${_m[d.month - 1]}';
}

class _MealTypePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _MealTypePicker({required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final i = mealTypes.indexOf(value);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: p.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: p.line)),
      child: LayoutBuilder(builder: (_, box) {
        final w = box.maxWidth / mealTypes.length;
        return SizedBox(
          height: 42,
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutBack,
              left: w * i,
              top: 0,
              bottom: 0,
              width: w,
              child: Container(decoration: BoxDecoration(color: p.forest, borderRadius: BorderRadius.circular(12))),
            ),
            Row(
              children: mealTypes
                  .map((m) => Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onChanged(m),
                          child: Center(
                            child: AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.5,
                                  color: m == value ? p.forestInk : p.muted),
                              child: Text(m),
                            ),
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ]),
        );
      }),
    );
  }
}

class _StaggerIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _StaggerIn({required this.index, required this.child});
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 380 + index * 90),
        curve: Curves.easeOutCubic,
        builder: (_, v, ch) => Opacity(
          opacity: v,
          child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: ch),
        ),
        child: child,
      );
}

class _ScanLine extends StatefulWidget {
  const _ScanLine();
  @override
  State<_ScanLine> createState() => _ScanLineState();
}

class _ScanLineState extends State<_ScanLine> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    return LayoutBuilder(builder: (_, box) {
      return AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final y = Curves.easeInOut.transform(_c.value) * (box.maxHeight + 90) - 90;
          return Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              top: y,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, p.saffron.withValues(alpha: 0.5)],
                  ),
                  border: Border(bottom: BorderSide(color: p.saffron, width: 2)),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }
}

class _ScanCorners extends StatelessWidget {
  const _ScanCorners();
  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.all(14), child: CustomPaint(painter: _CornerPainter(Palette.of(context).saffron)));
}

class _CornerPainter extends CustomPainter {
  final Color c;
  _CornerPainter(this.c);
  @override
  void paint(Canvas canvas, Size s) {
    final pt = Paint()
      ..color = c
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const l = 26.0;
    for (final (x, y, dx, dy) in [
      (0.0, 0.0, 1.0, 1.0),
      (s.width, 0.0, -1.0, 1.0),
      (0.0, s.height, 1.0, -1.0),
      (s.width, s.height, -1.0, -1.0),
    ]) {
      canvas.drawLine(Offset(x, y), Offset(x + l * dx, y), pt);
      canvas.drawLine(Offset(x, y), Offset(x, y + l * dy), pt);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter o) => false;
}
