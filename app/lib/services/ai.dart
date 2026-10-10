import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../models.dart';
import 'food_db.dart';

class AiResult {
  final String dish, note;
  final List<FoodItem> items;
  AiResult(this.dish, this.note, this.items);
}

/// Thrown with a message that is safe to show to the user.
class AiException implements Exception {
  final String message;
  AiException(this.message);
  @override
  String toString() => message;
}

/// Calls our AI server (api/analyze on Vercel; Gemini runs there, the key never reaches the app).
/// The server address comes from config/api_url.txt at build time: either the full
/// address (https://yourdomain.com/api/analyze.php) or a Vercel site (https://x.vercel.app).
const String kApiUrl = String.fromEnvironment('API_URL');

/// The AI names each food; when it's in our built-in food list the numbers come
/// from the list, which keeps the reply short (fast) and the numbers consistent.
class AiService {
  AiService._();
  static final instance = AiService._();

  Future<AiResult> analyzePhoto(Uint8List jpegBytes) async =>
      _call({'imageBase64': base64Encode(jpegBytes)});

  Future<AiResult> analyzeText(String text) => _call({'text': text});

  Future<AiResult> _call(Map<String, dynamic> data) async {
    final db = FoodDb.instance;
    final names = await db.names();
    if (kApiUrl.isEmpty) throw AiException('AI scanning is not switched on yet. Use Search or Barcode for now.');
    try {
      final token = await FirebaseAuth.instance.currentUser?.getIdToken();
      final res = await http
          .post(Uri.parse(kApiUrl.contains('/api/') ? kApiUrl : '$kApiUrl/api/analyze'),
              headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${token ?? ''}'},
              body: jsonEncode({...data, 'dbNames': names}))
          .timeout(const Duration(seconds: 60));
      final body = (() {
        try {
          return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
        } catch (_) {
          return <String, dynamic>{};
        }
      })();
      if (res.statusCode != 200) {
        final msg = body['error'] as String?;
        if (res.statusCode == 401) throw AiException('Please sign in again.');
        if (res.statusCode == 429 || res.statusCode == 400) throw AiException(msg ?? 'Could not scan right now. Try again.');
        throw AiException('Could not scan right now. Check your internet and try again.');
      }
      final m = body;
      final items = <FoodItem>[];
      for (final raw in (m['items'] as List?) ?? []) {
        final i = Map<String, dynamic>.from(raw as Map);
        final dbName = '${i['db'] ?? ''}';
        final grams = (i['grams'] as num?)?.toDouble() ?? 0;
        final portion = i['portion'] as String?;
        final hit = dbName.isNotEmpty ? db.find(dbName) : null;
        if (hit != null) {
          items.add(FoodDb.scaled(hit, grams, portion));
        } else if (i['kcal'] != null) {
          items.add(FoodItem.fromMap({...i, 'name': i['name'] ?? dbName}));
        } else {
          final byName = db.find('${i['name'] ?? dbName}');
          if (byName != null) items.add(FoodDb.scaled(byName, grams, portion));
        }
      }
      return AiResult('${m['dish'] ?? ''}', '${m['note'] ?? ''}', items);
    } catch (e) {
      if (e is AiException) rethrow;
      throw AiException('Could not scan right now. Check your internet and try again.');
    }
  }
}
