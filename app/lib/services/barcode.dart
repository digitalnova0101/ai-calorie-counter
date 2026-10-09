import 'dart:convert';

import 'package:http/http.dart' as http;

/// A packaged product from Open Food Facts. Values are per 100 g.
class Product {
  final String name;
  final String brand;
  final double kcal100;
  final double protein100;
  final double carbs100;
  final double fat100;
  final double servingGrams;

  Product({
    required this.name,
    required this.brand,
    required this.kcal100,
    required this.protein100,
    required this.carbs100,
    required this.fat100,
    required this.servingGrams,
  });
}

double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// Looks up a barcode on Open Food Facts (free, no key).
/// Returns null when the product is not in the database.
Future<Product?> lookupBarcode(String code) async {
  final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v2/product/${Uri.encodeComponent(code)}.json'
      '?fields=product_name,brands,nutriments,serving_quantity');
  final res = await http.get(uri, headers: {
    'User-Agent': 'ThaliApp/1.0 (calorie tracker)',
  }).timeout(const Duration(seconds: 15));
  if (res.statusCode == 404) return null;
  if (res.statusCode != 200) {
    throw Exception('Lookup failed (${res.statusCode})');
  }
  final body = jsonDecode(res.body) as Map<String, dynamic>;
  if (body['status'] != 1 || body['product'] == null) return null;
  final p = body['product'] as Map<String, dynamic>;
  final n = (p['nutriments'] as Map?)?.cast<String, dynamic>() ?? {};

  var kcal = _n(n['energy-kcal_100g']);
  if (kcal == 0 && n['energy_100g'] != null) {
    kcal = _n(n['energy_100g']) / 4.184; // kJ -> kcal
  }
  final serving = _n(p['serving_quantity']);

  return Product(
    name: '${p['product_name'] ?? ''}'.trim().isEmpty
        ? 'Packaged food'
        : '${p['product_name']}'.trim(),
    brand: '${p['brands'] ?? ''}'.split(',').first.trim(),
    kcal100: kcal,
    protein100: _n(n['proteins_100g']),
    carbs100: _n(n['carbohydrates_100g']),
    fat100: _n(n['fat_100g']),
    servingGrams: serving > 0 ? serving : 100,
  );
}
