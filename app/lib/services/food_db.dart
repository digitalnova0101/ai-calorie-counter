import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models.dart';

/// Offline list of common foods from India and around the world (assets/foods_in.json).
/// Values are approximate, per the listed home-style serving.
class FoodDb {
  FoodDb._();
  static final instance = FoodDb._();

  List<FoodItem>? _foods;

  Future<List<FoodItem>> all() async {
    if (_foods != null) return _foods!;
    final raw = await rootBundle.loadString('assets/foods_in.json');
    _foods = (jsonDecode(raw) as List)
        .map((e) => FoodItem.fromMap((e as Map).cast<String, dynamic>()))
        .toList();
    return _foods!;
  }

  /// Names sent to the AI so it can answer with a list name instead of numbers.
  Future<List<String>> names() async => (await all()).map((f) => f.name).toList();

  Future<List<FoodItem>> search(String q) async {
    final foods = await all();
    final s = q.trim().toLowerCase();
    if (s.isEmpty) return foods;
    final starts = <FoodItem>[], contains = <FoodItem>[];
    for (final f in foods) {
      final n = f.name.toLowerCase();
      if (n.startsWith(s)) {
        starts.add(f);
      } else if (n.contains(s)) {
        contains.add(f);
      }
    }
    return [...starts, ...contains];
  }

  static String _norm(String t) => t
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Finds a list food by name ("Roti / Chapati" also matches "roti").
  FoodItem? find(String name) {
    final foods = _foods;
    if (foods == null) return null;
    final n = _norm(name);
    if (n.isEmpty) return null;
    List<String> names(FoodItem f) =>
        [_norm(f.name), ...f.name.split('/').map(_norm)].where((x) => x.isNotEmpty).toList();
    for (final f in foods) {
      if (names(f).contains(n)) return f;
    }
    for (final f in foods) {
      if (names(f).any((m) => m.startsWith('$n ') || n.startsWith('$m '))) return f;
    }
    return null;
  }

  /// A list food scaled to [grams] eaten.
  static FoodItem scaled(FoodItem f, double grams, String? portion) {
    final g = grams > 0 ? grams : f.grams;
    final k = f.grams > 0 ? g / f.grams : 1.0;
    double r1(double v) => (v * k * 10).roundToDouble() / 10;
    return FoodItem(
      name: f.name,
      portion: (portion == null || portion.isEmpty) ? f.portion : portion,
      grams: g.roundToDouble(),
      kcal: f.kcal * k,
      protein: r1(f.protein),
      carbs: r1(f.carbs),
      fat: r1(f.fat),
      src: 'db',
    );
  }
}
