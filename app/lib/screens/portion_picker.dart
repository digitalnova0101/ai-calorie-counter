import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/ui.dart';

class _Unit {
  final String id, name, emoji, hint;
  final double? grams; // null = "piece / serving" (relative to the AI portion)
  const _Unit(this.id, this.name, this.emoji, this.grams, this.hint);
}

const _units = <_Unit>[
  _Unit('katori', 'Katori', '🥣', 150, '150 g'),
  _Unit('small', 'Small katori', '🥣', 100, '100 g'),
  _Unit('plate', 'Full plate', '🍽️', 300, '300 g'),
  _Unit('half', 'Half plate', '🍽️', 150, '150 g'),
  _Unit('glass', 'Glass', '🥛', 250, '250 ml'),
  _Unit('cup', 'Cup', '☕', 150, '150 ml'),
  _Unit('piece', 'Piece / serving', '🫓', null, 'as shown'),
  _Unit('tbsp', 'Tablespoon', '🥄', 15, '15 g'),
  _Unit('gram', 'Grams', '⚖️', 1, 'exact'),
];

/// Indian portion picker. Returns true when the item was changed.
Future<bool?> showPortionPicker(BuildContext context, FoodItem item) =>
    showAppSheet<bool>(context, (_) => _PortionSheet(item: item));

class _PortionSheet extends StatefulWidget {
  final FoodItem item;
  const _PortionSheet({required this.item});
  @override
  State<_PortionSheet> createState() => _PortionSheetState();
}

class _PortionSheetState extends State<_PortionSheet> {
  late String _unit;
  late double _count;
  final _ctrl = TextEditingController();

  FoodItem get it => widget.item;
  bool get _hasGrams => it.grams > 0;
  _Unit get _u => _units.firstWhere((u) => u.id == _unit);

  @override
  void initState() {
    super.initState();
    _unit = _hasGrams ? _guess() : 'piece';
    final cur = it.grams * it.mult;
    if (_unit == 'piece') {
      _count = it.mult;
    } else if (_unit == 'gram') {
      _count = cur.roundToDouble();
    } else {
      _count = ((cur / _u.grams! * 2).round() / 2).clamp(0.5, 20.0);
    }
    _ctrl.text = _fmt(_count);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _guess() {
    final p = it.portion.toLowerCase();
    if (RegExp(r'glass|ml').hasMatch(p)) return 'glass';
    if (p.contains('cup')) return 'cup';
    if (p.contains('plate')) return 'plate';
    if (RegExp(r'bowl|katori').hasMatch(p)) return 'katori';
    if (RegExp(r'tbsp|spoon').hasMatch(p)) return 'tbsp';
    return 'piece';
  }

  static String _fmt(double v) => v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  double get _mult {
    if (_unit == 'piece' || !_hasGrams) return _count;
    return _u.grams! * _count / it.grams;
  }

  void _setUnit(_Unit u) {
    if (u.grams != null && !_hasGrams) return;
    final cur = it.grams * _mult;
    setState(() {
      _unit = u.id;
      if (u.id == 'piece') {
        _count = ((_mult * 2).round() / 2).clamp(0.5, 20.0);
      } else if (u.id == 'gram') {
        _count = cur.roundToDouble();
      } else {
        _count = ((cur / u.grams! * 2).round() / 2).clamp(0.5, 20.0);
      }
      _ctrl.text = _fmt(_count);
    });
  }

  void _bump(int dir) {
    final step = _unit == 'gram' ? 10.0 : 0.5;
    setState(() {
      _count = ((_count + dir * step) * 10).roundToDouble() / 10;
      if (_count < step) _count = step;
      _ctrl.text = _fmt(_count);
    });
  }

  void _apply() {
    final m = _mult;
    if (m <= 0) {
      toast(context, 'Enter an amount');
      return;
    }
    it.mult = (m * 100).roundToDouble() / 100;
    final g = (it.grams * m).round();
    final liquid = _unit == 'glass' || _unit == 'cup';
    final c = _fmt(_count);
    it.portionLabel = _unit == 'gram'
        ? '$g g'
        : _unit == 'piece'
            ? '$c × ${it.portion.isEmpty ? 'serving' : it.portion}'
            : '$c ${_u.name.toLowerCase()}${_count > 1 ? 's' : ''}, $g ${liquid ? 'ml' : 'g'}';
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final p = Palette.of(context);
    final preview = Totals.of([FoodItem.fromMap({...it.toMap(), 'mult': _mult})]);
    final liquid = _unit == 'glass' || _unit == 'cup';
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        H2(it.name),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.05,
          children: _units.map((u) {
            final on = u.id == _unit, disabled = u.grams != null && !_hasGrams;
            return Opacity(
              opacity: disabled ? 0.4 : 1,
              child: Pressable(
                onTap: () => _setUnit(u),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: on ? p.saffron.withValues(alpha: 0.1) : p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: on ? p.saffron : p.line, width: 1.5),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(u.emoji, style: TextStyle(fontSize: u.id == 'small' ? 22 : 30)),
                    const SizedBox(height: 4),
                    Text(u.name,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5)),
                    Text(u.id == 'piece' ? (it.portion.isEmpty ? '1 serving' : it.portion) : u.hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.muted, fontSize: 11)),
                  ]),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                _unit == 'gram'
                    ? 'How many grams?'
                    : _unit == 'piece'
                        ? 'How many servings?'
                        : 'How many ${_u.name.toLowerCase()}s?',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            if (_hasGrams) Muted('About ${(it.grams * _mult).round()} ${liquid ? 'ml' : 'g'}', size: 12.5),
            const SizedBox(height: 10),
            NumberStepper(
              controller: _ctrl,
              decimal: true,
              onMinus: () => _bump(-1),
              onPlus: () => _bump(1),
              onChanged: (v) => setState(() => _count = double.tryParse(v.replaceAll(',', '.')) ?? 0),
            ),
          ]),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          MacroChip('${preview.kcal.round()} kcal', p.saffron),
          MacroChip('P ${preview.protein.round()}g', p.leaf),
          MacroChip('C ${preview.carbs.round()}g', p.wheat),
          MacroChip('F ${preview.fat.round()}g', p.chili),
        ]),
        const SizedBox(height: 14),
        SizedBox(
          height: 54,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: p.saffron, foregroundColor: const Color(0xFF2B1400)),
            onPressed: _apply,
            child: const Text('Use this portion'),
          ),
        ),
      ]),
    );
  }
}
