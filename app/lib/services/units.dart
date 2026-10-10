import 'dart:ui' show PlatformDispatcher;

import '../models.dart';

/// Metric (kg, cm, km, L) or imperial (lb, ft/in, mi, fl oz).
/// Everything is stored in metric; this only changes what people see and type.
class Units {
  Units._();
  static bool imperial = _deviceImperial();

  static const lbPerKg = 2.20462, cmPerIn = 2.54, miPerKm = 0.621371, mlPerOz = 29.5735;

  /// US, Liberia and Myanmar use pounds and feet day to day.
  static bool _deviceImperial() {
    try {
      final c = PlatformDispatcher.instance.locale.countryCode?.toUpperCase() ?? '';
      return const {'US', 'LR', 'MM'}.contains(c);
    } catch (_) {
      return false;
    }
  }

  static bool deviceDefault() => _deviceImperial();

  /// Uses the profile's choice, or the phone's country when none is saved.
  static void apply(Profile p) {
    imperial = p.units.isEmpty ? _deviceImperial() : p.units == 'imperial';
  }

  // ---- weight ----
  static String get w => imperial ? 'lb' : 'kg';
  static double toW(double kg) => imperial ? kg * lbPerKg : kg;
  static double fromW(double v) => imperial ? v / lbPerKg : v;
  static String weight(double kg, [int dp = 1]) => '${toW(kg).toStringAsFixed(dp)} $w';

  /// A weekly pace, e.g. "0.50 kg / week" or "1.1 lb / week".
  static String pace(double kgWeek) =>
      imperial ? '${toW(kgWeek).toStringAsFixed(1)} lb / week' : '${kgWeek.toStringAsFixed(2)} kg / week';

  // ---- height ----
  static String height(double cm) {
    if (!imperial) return '${cm.round()} cm';
    final inches = (cm / cmPerIn).round();
    return "${inches ~/ 12}′ ${inches % 12}″";
  }

  // ---- distance ----
  static String dist(double km) =>
      imperial ? '${(km * miPerKm).toStringAsFixed(1)} mi' : '${km.toStringAsFixed(1)} km';

  // ---- water ----
  static String water(num ml) => imperial ? '${(ml / mlPerOz).round()} oz' : '${(ml / 1000).toStringAsFixed(2)} L';
  static String glass() => imperial ? '8 oz' : '250 ml';
}
