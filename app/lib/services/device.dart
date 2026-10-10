import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:health/health.dart';
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

// ============================================================
// Photo helpers
// ============================================================

/// 160 px square JPEG thumbnail (base64) for the meal list.
Future<String?> makeThumb(Uint8List bytes) => compute(_thumb, bytes);

String? _thumb(Uint8List bytes) {
  final src = img.decodeImage(bytes);
  if (src == null) return null;
  final side = src.width < src.height ? src.width : src.height;
  final sq = img.copyCrop(src,
      x: (src.width - side) ~/ 2, y: (src.height - side) ~/ 2, width: side, height: side);
  final small = img.copyResize(sq, width: 160, height: 160);
  return base64Encode(img.encodeJpg(small, quality: 72));
}

// ============================================================
// Simple local settings
// ============================================================
class Prefs {
  Prefs._();
  static SharedPreferences? _p;
  static Future<SharedPreferences> get _sp async =>
      _p ??= await SharedPreferences.getInstance();

  static Future<bool> getBool(String k, [bool d = false]) async =>
      (await _sp).getBool(k) ?? d;
  static Future<void> setBool(String k, bool v) async => (await _sp).setBool(k, v);
  static Future<String> getString(String k, String d) async =>
      (await _sp).getString(k) ?? d;
  static Future<void> setString(String k, String v) async =>
      (await _sp).setString(k, v);
}

// ============================================================
// Steps from Health Connect (Android) / Apple Health (iPhone)
// ============================================================
class StepsService {
  StepsService._();
  static final instance = StepsService._();
  final _health = Health();
  bool _configured = false;

  Future<void> _setup() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Asks for permission once. Returns true when steps can be read.
  Future<bool> connect() async {
    try {
      await _setup();
      final ok = await _health.requestAuthorization(
        [HealthDataType.STEPS],
        permissions: [HealthDataAccess.READ],
      );
      await Prefs.setBool('steps_connected', ok);
      return ok;
    } catch (e) {
      debugPrint('Health connect failed: $e');
      return false;
    }
  }

  Future<bool> get isConnected => Prefs.getBool('steps_connected');

  /// Total steps for [day] (midnight to midnight, or to now for today).
  Future<int?> stepsFor(DateTime day) async {
    try {
      await _setup();
      final start = DateTime(day.year, day.month, day.day);
      final end0 = start.add(const Duration(days: 1));
      final now = DateTime.now();
      final end = end0.isAfter(now) ? now : end0;
      return await _health.getTotalStepsInInterval(start, end);
    } catch (e) {
      debugPrint('Read steps failed: $e');
      return null;
    }
  }

  /// Copies steps for past days from Health Connect into the app.
  /// The last 30 days once a day, otherwise just today and yesterday.
  /// [save] writes one day; returns how many days were updated.
  Future<int> syncRecent(Future<void> Function(DateTime day, int steps) save, {bool force = false}) async {
    if (!await isConnected) return 0;
    final now = DateTime.now();
    final today = '${now.year}-${now.month}-${now.day}';
    final full = force || await Prefs.getString('steps_full_sync', '') != today;
    final days = full ? 30 : 2;
    var n = 0;
    for (var i = 0; i < days; i++) {
      final d = now.subtract(Duration(days: i));
      final v = await stepsFor(d);
      if (v != null && v > 0) {
        await save(d, v);
        n++;
      }
    }
    if (full) await Prefs.setString('steps_full_sync', today);
    return n;
  }
}

// ============================================================
// Reminders (local notifications, work even when the app is closed)
// ============================================================
class Reminders {
  Reminders._();
  static final instance = Reminders._();
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Meal, water and weigh-in reminders',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  /// Picks a time zone that matches the phone's clock right now (name first,
  /// then the UTC offset), so reminders fire at local time anywhere.
  static tz.Location _deviceLocation() {
    final now = DateTime.now();
    final off = now.timeZoneOffset.inMilliseconds, abbr = now.timeZoneName;
    tz.Location? byOffset;
    for (final loc in tz.timeZoneDatabase.locations.values) {
      final z = loc.timeZone(now.millisecondsSinceEpoch);
      if (z.offset != off) continue;
      if (z.abbreviation == abbr) return loc;
      byOffset ??= loc;
    }
    return byOffset ?? tz.UTC;
  }

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_deviceLocation());
    await _plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    ));
    _ready = true;
  }

  Future<bool> askPermission() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    final a = await android?.requestNotificationsPermission();
    final i = await ios?.requestPermissions(alert: true, sound: true);
    return (a ?? true) && (i ?? true);
  }

  tz.TZDateTime _next(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  Future<void> _daily(int id, String title, String body, int h, int m) =>
      _plugin.zonedSchedule(id, title, body, _next(h, m), _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.time);

  /// Re-schedules everything from the saved settings.
  Future<void> apply() async {
    await init();
    await _plugin.cancelAll();
    final bf = await Prefs.getBool('rem_bf');
    final water = await Prefs.getBool('rem_water');
    final w = await Prefs.getBool('rem_w');
    (int, int) hm(String s) {
      final p = s.split(':');
      return (int.tryParse(p[0]) ?? 8, int.tryParse(p.length > 1 ? p[1] : '0') ?? 0);
    }

    if (bf) {
      final (h, m) = hm(await Prefs.getString('rem_bf_time', '08:30'));
      await _daily(1, 'Breakfast time', 'Snap your breakfast so we can count it.', h, m);
    }
    if (w) {
      final (h, m) = hm(await Prefs.getString('rem_w_time', '07:30'));
      await _daily(2, 'Weigh-in', 'Step on the scale before breakfast and log your weight.', h, m);
    }
    if (water) {
      for (var i = 0; i < 7; i++) {
        await _daily(10 + i, 'Drink water', 'Time for a glass of water.', 9 + i * 2, 0);
      }
    }
  }
}
