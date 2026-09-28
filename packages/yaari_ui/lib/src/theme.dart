import 'package:flutter/material.dart';

/// Brand palette, sampled from the reference photograph: a saturated red
/// against a cool sky blue, grounded by slate and a warm off-white.
class YaariColors {
  // Pointed at the current brand. These are the legacy names the splash,
  // sign-in and map still use; they carried the old terracotta until now.
  static const ember = Color(0xFFC9212B);
  static const emberDeep = Color(0xFF8A1720);
  static const emberTint = Color(0xFFFDF0F1);

  static const sky = Color(0xFF8FD8DE);
  static const slate = Color(0xFF4C6B78);
  static const slateTint = Color(0xFFE6F4F5);

  static const chalk = Color(0xFFF6F3EE);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF211D1A);
  static const inkDim = Color(0xFF7D766C);
  static const line = Color(0xFFE7E1D6);

  static const good = Color(0xFF2F7A52);
  static const warn = Color(0xFFA86A12);
}

/// Which app is running. Only the primary accent differs.
enum YaariBrand { customer, provider }

/// The two faces, namespaced for the package that ships them.
///
/// Fraunces carries the headings; Manrope carries everything that is read at
/// length or tapped. Referenced through constants because getting the
/// `packages/` prefix wrong fails silently — you simply get the system font.
class YaariType {
  static const body = 'packages/yaari_ui/Manrope';
  static const display = 'packages/yaari_ui/Fraunces';
}

class YaariTheme {
  static Color accentOf(YaariBrand brand) =>
      brand == YaariBrand.customer ? YaariColors.ember : YaariColors.slate;

  static ThemeData build(YaariBrand brand) {
    final accent = accentOf(brand);

    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: YaariColors.chalk,
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        primary: accent,
        surface: YaariColors.card,
        brightness: Brightness.light,
      ),
      // Fonts declared by a package are namespaced; without the prefix
      // Flutter silently falls back to the platform face.
      fontFamily: YaariType.body,
      textTheme: const TextTheme(
        // The two display sizes are set in Fraunces. Everything a person
        // reads or taps stays in Manrope: the serif is there to give the
        // headings a different voice, not to be worked for a living.
        displaySmall: TextStyle(
          fontFamily: YaariType.display,
          fontSize: 30, fontWeight: FontWeight.w600, color: YaariColors.ink,
          letterSpacing: -0.6, height: 1.1),
        headlineMedium: TextStyle(
          fontFamily: YaariType.display,
          fontSize: 24, fontWeight: FontWeight.w600, color: YaariColors.ink,
          letterSpacing: -0.3, height: 1.15),
        titleLarge: TextStyle(
          fontSize: 18, fontWeight: FontWeight.w700, color: YaariColors.ink, letterSpacing: -0.2),
        titleMedium: TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700, color: YaariColors.ink),
        bodyMedium: TextStyle(fontSize: 14, color: YaariColors.ink, height: 1.45),
        bodySmall: TextStyle(fontSize: 12.5, color: YaariColors.inkDim, height: 1.4),
        labelSmall: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w800, color: YaariColors.inkDim,
          letterSpacing: 0.7),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: YaariColors.chalk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 17, fontWeight: FontWeight.w700, color: YaariColors.ink),
        iconTheme: IconThemeData(color: YaariColors.ink),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: BorderSide(color: accent, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
        ),
      ),
      cardTheme: CardThemeData(
        color: YaariColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: YaariColors.line),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: YaariColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: YaariColors.line, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: YaariColors.line, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: BorderSide(color: accent, width: 1.8),
        ),
      ),
      dividerTheme: const DividerThemeData(color: YaariColors.line, thickness: 1, space: 1),
    );
  }
}

/// Prices are stored as integer pence and only ever formatted at the edge.
String formatPence(int pence) {
  if (pence % 100 == 0) return '£${pence ~/ 100}';
  return '£${(pence / 100).toStringAsFixed(2)}';
}

/// A price with the unit it is sold in.
///
/// 'job' is deliberately unsuffixed — "£85" already reads as the price of the
/// job. Everything else needs saying, because "£18" against a by-the-room
/// clean means something very different from "£18/room". Kept to the short
/// "/unit" form: it has to fit a two-line grid tile, and "from £20 per visit"
/// did not.
String formatRate(int pence, String unit) {
  const suffix = <String, String>{
    'hour': '/hr',
    'room': '/room',
    'day': '/day',
    'visit': '/visit',
    'week': '/wk',
  };
  return '${formatPence(pence)}${suffix[unit] ?? ''}';
}

/// A base price with a tier's uplift applied, rounded to the nearest 50p.
///
/// Must match quote_service() in the database digit for digit — that is what
/// charges the customer, and a screen that shows £102 for a job the server
/// prices at £101.50 has lied to them. Both round half away from zero.
int tierPrice(int basePence, int upliftBps) =>
    ((basePence * (10000 + upliftBps) / 10000) / 50).round() * 50;

String formatDistance(double metres) {
  final miles = metres / 1609.34;
  if (miles < 0.1) return 'nearby';
  return '${miles.toStringAsFixed(1)} mi';
}
