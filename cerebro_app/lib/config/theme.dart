// App theme — warm cream palette with thick borders and 3D shadows

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CerebroTheme {
  static const Color cream = Color(0xFFFEF5E8);
  static const Color creamMid = Color(0xFFF5E6D3);
  static const Color creamDark = Color(0xFFE8D5C4);

  static const Color pinkPop = Color(0xFFFF6B9D);
  static const Color pinkSoft = Color(0xFFFFB5C5);
  static const Color pinkDark = Color(0xFFE85A8A);

  static const Color coral = Color(0xFFFF8C7A);
  static const Color coralDark = Color(0xFFE67A6A);

  static const Color sage = Color(0xFF7BC9A0);
  static const Color sageDark = Color(0xFF5FB085);

  static const Color gold = Color(0xFFFFCA4E);
  static const Color goldDark = Color(0xFFE5B345);

  static const Color sky = Color(0xFF7DD3FC);
  static const Color skyDark = Color(0xFF5BC0EB);

  static const Color lavender = Color(0xFFB8A9E8);
  static const Color lavenderDark = Color(0xFF9D8AD4);

  static const Color outline = Color(0xFF4A3F35);
  static const Color brown = Color(0xFF8B7355);
  static const Color brownDark = Color(0xFF5C4D3A);
  static const Color shadow = Color(0x404A3F35);
  static const Color shadowDark = Color(0x664A3F35);

  static const Color olive = Color(0xFF98A869);
  static const Color oliveDark = Color(0xFF58772F);
  static const Color pinkAccent = Color(0xFFFEA9D3);
  static const Color pinkAccentDeep = Color(0xFFE890B8);
  static const Color greenPale = Color(0xFFF9FDEC);
  static const Color pinkLight = Color(0xFFFFD5F5);
  static const Color creamWarm = Color(0xFFFDEFDB);
  static const Color blueLight = Color(0xFFDDF6FF);
  static const Color coralSoft = Color(0xFFF7AEAE);
  static const Color orangeWarm = Color(0xFFFFBC5C);
  static const Color text1 = Color(0xFF2C3322);
  static const Color text2 = Color(0xFF4D5A3A);
  static const Color text3 = Color(0xFF8A9668);
  static const Color inputBorder = Color(0xFFC0C99A);
  static const Color dividerGreen = Color(0xFFDDE4C8);
  static const Color inputBg = Color(0xFFFEFDFB);

  static const Color primaryPurple = lavender;
  static const Color primaryBlue = sky;
  static const Color accentGreen = sage;
  static const Color accentOrange = gold;
  static const Color accentRed = coral;
  static const Color xpGold = gold;

  static Border get thickBorder =>
      Border.all(color: outline, width: 4);

  static Border get thinBorder =>
      Border.all(color: outline, width: 3);

  static BoxShadow get shadow3D => BoxShadow(
        color: shadowDark,
        offset: const Offset(0, 4),
        blurRadius: 0,
      );

  static BoxShadow get shadow3DSmall => BoxShadow(
        color: shadowDark,
        offset: const Offset(0, 3),
        blurRadius: 0,
      );

  static BoxShadow get shadow3DLarge => BoxShadow(
        color: shadowDark,
        offset: const Offset(0, 6),
        blurRadius: 0,
      );

  static BoxDecoration cuteCard({
    Color? color,
    double radius = 20,
    bool large = false,
  }) {
    return BoxDecoration(
      color: color ?? Colors.white,
      border: Border.all(color: outline, width: large ? 5 : 4),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [large ? shadow3DLarge : shadow3D],
    );
  }

  static BoxDecoration gradientCard({
    required List<Color> colors,
    double radius = 20,
    bool large = false,
  }) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: colors,
      ),
      border: Border.all(color: outline, width: large ? 5 : 4),
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [large ? shadow3DLarge : shadow3D],
    );
  }

  //  LIGHT THEME (Toca Boca Style)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: cream,
      colorScheme: ColorScheme.light(
        primary: pinkPop,
        secondary: sage,
        tertiary: lavender,
        surface: cream,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: outline,
        outline: outline,
      ),

      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: outline),
        displayMedium: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: outline),
        headlineLarge: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: outline),
        headlineMedium: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: outline),
        titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: outline),
        titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: outline),
        bodyLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: outline),
        bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: outline),
        bodySmall: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: brown),
        labelLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: outline,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: outline, width: 4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: pinkPop,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: outline, width: 4),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: outline, width: 3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 3),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline, width: 3),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: pinkPop, width: 3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coral, width: 3),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: coral, width: 3),
        ),
        hintStyle: TextStyle(color: creamDark, fontWeight: FontWeight.w600),
        labelStyle: TextStyle(color: outline, fontWeight: FontWeight.w700, fontSize: 14),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: pinkSoft.withOpacity(0.3),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: pinkPop);
          }
          return GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: brown);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: pinkPop, size: 26);
          }
          return IconThemeData(color: brown, size: 24);
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: pinkPop,
        unselectedItemColor: brown,
        showUnselectedLabels: true,
      ),
    );
  }

  //  DARK THEME (keep minimal for now)
  static ThemeData get darkTheme => lightTheme;
}
