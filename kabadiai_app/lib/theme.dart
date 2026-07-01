import 'package:flutter/material.dart';

class KabadiTheme {
  // Brand colours — exposed as static consts for use across the app
  static const Color primary   = Color(0xFF00C897);  // KabadiAI green
  static const Color secondary = Color(0xFF2A78D6);  // blue
  static const Color hazard    = Color(0xFFE34948);  // red for e-waste
  static const Color cardBg    = Color(0xFF1C2333);
  static const Color surface   = Color(0xFF161B22);
  static const Color bg        = Color(0xFF0D1117);

  static ThemeData dark() {
    const colorDark    = Color(0xFF0D1117);
    const colorSurface = Color(0xFF161B22);
    const colorCard    = Color(0xFF1C2333);
    const colorPrimary = primary;
    const colorSecondary = secondary;
    const colorHazard  = hazard;

    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: colorDark,
      colorScheme: const ColorScheme.dark(
        primary:   colorPrimary,
        secondary: colorSecondary,
        surface:   colorSurface,
        error:     colorHazard,
      ),
      // Use the system default font — avoids google_fonts dependency
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: 'Roboto',
      ),
      cardTheme: CardThemeData(
        color: colorCard,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: colorDark,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.black,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  static ThemeData light() => dark(); // always use dark
}
