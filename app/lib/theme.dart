import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// App colours. Light and dark sets mirror the website design.
class Palette {
  final Color bg, surface, ink, muted, line, steel, forest, forestInk;
  final Color saffron, leaf, wheat, chili, water, danger;
  final Color heroA, heroB, plateTrack, plateIn;

  const Palette({
    required this.bg,
    required this.surface,
    required this.ink,
    required this.muted,
    required this.line,
    required this.steel,
    required this.forest,
    required this.forestInk,
    required this.saffron,
    required this.leaf,
    required this.wheat,
    required this.chili,
    required this.water,
    required this.danger,
    required this.heroA,
    required this.heroB,
    required this.plateTrack,
    required this.plateIn,
  });

  static const light = Palette(
    bg: Color(0xFFEEF2F0),
    surface: Color(0xFFFFFFFF),
    ink: Color(0xFF14211C),
    muted: Color(0xFF63716B),
    line: Color(0xFFDBE3DF),
    steel: Color(0xFFCFD8D4),
    forest: Color(0xFF123D2F),
    forestInk: Color(0xFFE9F3EE),
    saffron: Color(0xFFEF8A17),
    leaf: Color(0xFF2F9C6A),
    wheat: Color(0xFFD9A92E),
    chili: Color(0xFFD24B3E),
    water: Color(0xFF2F8FD1),
    danger: Color(0xFFC0352B),
    heroA: Color(0xFFE2F3E9),
    heroB: Color(0xFFFFFFFF),
    plateTrack: Color(0xFFE1E8E4),
    plateIn: Color(0xFFF2F6F4),
  );

  static const dark = Palette(
    bg: Color(0xFF0C1512),
    surface: Color(0xFF15211C),
    ink: Color(0xFFE7F0EB),
    muted: Color(0xFF93A39B),
    line: Color(0xFF2A3A33),
    steel: Color(0xFF2A3A33),
    forest: Color(0xFF1D5A44),
    forestInk: Color(0xFFE9F3EE),
    saffron: Color(0xFFFF9D33),
    leaf: Color(0xFF4CC28A),
    wheat: Color(0xFFE8BD4A),
    chili: Color(0xFFF06A5C),
    water: Color(0xFF4FB0F0),
    danger: Color(0xFFFF7A6E),
    heroA: Color(0xFF16261F),
    heroB: Color(0xFF111B17),
    plateTrack: Color(0xFF22332B),
    plateIn: Color(0xFF1A2923),
  );

  static Palette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}

/// Big, characterful numbers and headings.
TextStyle display(BuildContext context, double size,
        {FontWeight weight = FontWeight.w800, Color? color}) =>
    GoogleFonts.unbounded(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Palette.of(context).ink,
      letterSpacing: -0.5,
      height: 1.1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Palette.dark : Palette.light;
  final base = ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(
      seedColor: p.forest,
      brightness: b,
      surface: p.surface,
      primary: b == Brightness.dark ? p.leaf : p.forest,
      error: p.danger,
    ),
    scaffoldBackgroundColor: p.bg,
  );
  final text = GoogleFonts.manropeTextTheme(base.textTheme)
      .apply(bodyColor: p.ink, displayColor: p.ink);
  return base.copyWith(
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg,
      foregroundColor: p.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.surface,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: p.leaf, width: 1.5)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: p.forest,
        foregroundColor: p.forestInk,
        minimumSize: const Size(0, 52),
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: p.ink,
        minimumSize: const Size(0, 52),
        side: BorderSide(color: p.line),
        backgroundColor: p.surface,
        textStyle: text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: p.ink,
      contentTextStyle: TextStyle(color: p.bg, fontWeight: FontWeight.w700),
      actionTextColor: p.saffron,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: p.bg,
      showDragHandle: true,
      dragHandleColor: p.steel,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    ),
    dividerTheme: DividerThemeData(color: p.line, space: 1, thickness: 1),
  );
}
