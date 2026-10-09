import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models.dart';
import '../services/barcode.dart';
import '../theme.dart';
import '../widgets/graphics.dart';
import '../widgets/ui.dart';
import 'result_screen.dart';

class BarcodeScreen extends StatefulWidget {
  final DateTime date;
  const BarcodeScreen({super.key, required this.date});
  @override
  State<BarcodeScreen> createState() => _BarcodeScreenState();
}

class _BarcodeScreenState extends State<BarcodeScreen> {
  final _controller = MobileScannerController(formats: const [
    BarcodeFormat.ean13,
    BarcodeFormat.ean8,
    BarcodeFormat.upcA,
    BarcodeFormat.upcE,
  ]);
  final _code = TextEditingController();
  final _grams = TextEditingController();
  bool _busy = false;
  String? _message;
  Product? _product;

  @override
  void dispose() {
    _controller.dispose();
    _code.dispose();
    _grams.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_busy) return;
    final code = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (code != null) await _lookup(code);
  }

  Future<void> _lookup(String code) async {
    setState(() {
      _busy = true;
      _message = 'Barcode $code';
      _product = null;
    });
    try {
      await _controller.stop();
    } catch (_) {}
    try {
      final p = await lookupBarcode(code);
      if (!mounted) return;
      setState(() {
        _product = p;
        if (p == null) {
          _message = "This product isn't in the food database yet. Try Search or Describe.";
        } else {
          _grams.text = p.servingGrams.round().toString();
        }
      });
    } catch (_) {
      if (mounted) setState(() => _message = "Couldn't reach the food database. Check your internet.");
    }
  }

  Future<void> _again() async {
    setState(() {
      _busy = false;
      _message = null;
      _product = null;
    });
    try {
      await _controller.start();
    } catch (_) {}
  }

  void _review() {
    final p = _product!;
    final g = double.tryParse(_grams.text.trim()) ?? 0;
    if (g <= 0) {
      toast(context, 'Enter how many grams');
      return;
    }
    final f = g / 100;
    Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => ResultScreen(date: widget.date, source: 'barcode', items: [
        FoodItem(
          name: p.brand.isEmpty ? p.name : '${p.name} (${p.brand})',
          portion: '${g.round()} g',
          grams: g,
          kcal: p.kcal100 * f,
          protein: p.protein100 * f,
          carbs: p.carbs100 * f,
          fat: p.fat100 * f,
        ),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pal = Palette.of(context);
    final prod = _product;
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: ListView(padding: EdgeInsets.fromLTRB(16, 4, 16, bottomGap(context)), children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: SizedBox(
            height: 280,
            child: Stack(fit: StackFit.expand, children: [
              MobileScanner(controller: _controller, onDetect: _onDetect),
              Center(
                child: Container(
                  width: 260,
                  height: 140,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white, width: 3),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        Muted(_message ?? 'Point the camera at the barcode on the pack.'),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: 'Or type the barcode number'),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            height: 50,
            child: FilledButton(
              onPressed: () {
                final c = _code.text.replaceAll(RegExp(r'\D'), '');
                if (c.length < 8) {
                  toast(context, 'Enter the full barcode number');
                } else {
                  _lookup(c);
                }
              },
              child: const Text('Find'),
            ),
          ),
        ]),
        const SizedBox(height: 14),
        if (_busy && prod == null && (_message ?? '').startsWith('Barcode'))
          const Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Shimmer(width: 200, height: 16),
              SizedBox(height: 10),
              Shimmer(width: 120),
              SizedBox(height: 14),
              Shimmer(height: 46, radius: 12),
            ]),
          ),
        if (_busy && prod == null && !(_message ?? '').startsWith('Barcode'))
          OutlinedButton(onPressed: _again, child: const Text('Scan another')),
        if (prod != null)
          Panel(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text(prod.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              if (prod.brand.isNotEmpty) Muted(prod.brand),
              const SizedBox(height: 10),
              Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                MacroChip('${prod.kcal100.round()} kcal', pal.saffron),
                MacroChip('P ${prod.protein100.toStringAsFixed(1)}g', pal.leaf),
                MacroChip('C ${prod.carbs100.toStringAsFixed(1)}g', pal.wheat),
                MacroChip('F ${prod.fat100.toStringAsFixed(1)}g', pal.chili),
                const Muted('per 100 g', size: 12),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _grams,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'How much did you have? (g or ml)'),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: OutlinedButton(onPressed: _again, child: const Text('Scan another'))),
                const SizedBox(width: 10),
                Expanded(child: FilledButton(onPressed: _review, child: const Text('Review'))),
              ]),
            ]),
          ),
      ]),
    );
  }
}
