// App theme — warm palette with light + dark mode support.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CerebroTheme {
  // Brightness notifier — synced by themeModeProvider.
  static final ValueNotifier<Brightness> brightnessNotifier =
      ValueNotifier(Brightness.light);

  static bool get _isDark => brightnessNotifier.value == Brightness.dark;

  // Light palette
  static const Color _lCream      = Color(0xFFFEF5E8);
  static const Color _lCreamMid   = Color(0xFFF5E6D3);
  static const Color _lCreamDark  = Color(0xFFE8D5C4);
  static const Color _lCreamWarm  = Color(0xFFFDEFDB);

  static const Color _lPinkPop    = Color(0xFFFF6B9D);
  static const Color _lPinkSoft   = Color(0xFFFFB5C5);
  static const Color _lPinkDark   = Color(0xFFE85A8A);
  static const Color _lPinkAcc    = Color(0xFFFEA9D3);
  static const Color _lPinkAccDp  = Color(0xFFE890B8);
  static const Color _lPinkLight  = Color(0xFFFFD5F5);

  static const Color _lCoral      = Color(0xFFFF8C7A);
  static const Color _lCoralDark  = Color(0xFFE67A6A);
  static const Color _lCoralSoft  = Color(0xFFF7AEAE);

  static const Color _lSage       = Color(0xFF7BC9A0);
  static const Color _lSageDark   = Color(0xFF5FB085);

  static const Color _lGold       = Color(0xFFFFCA4E);
  static const Color _lGoldDark   = Color(0xFFE5B345);
  static const Color _lOrangeWarm = Color(0xFFFFBC5C);

  static const Color _lSky        = Color(0xFF7DD3FC);
  static const Color _lSkyDark    = Color(0xFF5BC0EB);
  static const Color _lBlueLight  = Color(0xFFDDF6FF);

  static const Color _lLav        = Color(0xFFB8A9E8);
  static const Color _lLavDark    = Color(0xFF9D8AD4);

  static const Color _lOutline    = Color(0xFF4A3F35);
  static const Color _lBrown      = Color(0xFF8B7355);
  static const Color _lBrownDk    = Color(0xFF5C4D3A);
  static const Color _lShadow     = Color(0x404A3F35);
  static const Color _lShadowDk   = Color(0x664A3F35);

  static const Color _lOlive      = Color(0xFF98A869);
  static const Color _lOliveDk    = Color(0xFF58772F);
  static const Color _lGreenPale  = Color(0xFFF9FDEC);
  static const Color _lText1      = Color(0xFF2C3322);
  static const Color _lText2      = Color(0xFF4D5A3A);
  static const Color _lText3      = Color(0xFF8A9668);
  static const Color _lInputBord  = Color(0xFFC0C99A);
  static const Color _lDivGreen   = Color(0xFFDDE4C8);
  static const Color _lInputBg    = Color(0xFFFEFDFB);

  // Dark palette — warm brown tones, not cold slate.

  static const Color _dCream      = Color(0xFF1E1A17); // body bg  (BROWN 2)
  static const Color _dCreamMid   = Color(0xFF29221D); // card     (BROWN 3)
  static const Color _dCreamDark  = Color(0xFF312821); // elevated (BROWN 4)
  static const Color _dCreamWarm  = Color(0xFF191513); // deepest  (BROWN 1)

  static const Color _dPinkPop    = Color(0xFFE45EAF); // PINK 10 — punchy
  static const Color _dPinkSoft   = Color(0xFFBC2F88); // PINK 8  — muted fill
  static const Color _dPinkDark   = Color(0xFFD6409F); // PINK 9  — deep pop
  static const Color _dPinkAcc    = Color(0xFFF986C9); // PINK 11 — bright sticker
  static const Color _dPinkAccDp  = Color(0xFFD6409F); // PINK 9
  static const Color _dPinkLight  = Color(0xFF411C35); // PINK 4  — tinted chip bg

  static const Color _dCoral      = Color(0xFFFF8589); // RED 11 — punchy coral
  static const Color _dCoralDark  = Color(0xFFF26669); // RED 10 — deep coral
  static const Color _dCoralSoft  = Color(0xFF551C22); // RED 5  — tinted chip bg

  static const Color _dSage       = Color(0xFF35B979); // GREEN 10 — punchy sage
  static const Color _dSageDark   = Color(0xFF2C8C5E); // GREEN 8  — deep sage

  static const Color _dGold       = Color(0xFFFFCA4E); // keep warm gold
  static const Color _dGoldDark   = Color(0xFFE5B345);
  static const Color _dOrangeWarm = Color(0xFFFF9A3D); // boosted warmth

  static const Color _dSky        = Color(0xFF3CABFF); // BLUE 10
  static const Color _dSkyDark    = Color(0xFF0091FF); // BLUE 9
  static const Color _dBlueLight  = Color(0xFF102A4C); // BLUE 4 — tinted chip bg

  static const Color _dLav        = Color(0xFFC4B5FD); // brighter lilac
  static const Color _dLavDark    = Color(0xFF9B87F7);

  // Outline is BROWN 9 — the signature sticker stroke. Warm enough to
  // feel drawn, not so bright it vibrates against text.
  static const Color _dOutline    = Color(0xFFAD7F58); // BROWN 9
  static const Color _dBrown      = Color(0xFFDBB594); // BROWN 11 (body text)
  static const Color _dBrownDk    = Color(0xFFF2E1CA); // BROWN 12 (heading text)
  static const Color _dShadow     = Color(0x80000000); // 50% black
  static const Color _dShadowDk   = Color(0xAA000000); // 67% black

  static const Color _dOlive      = Color(0xFFB3C47F); // warm bright olive
  static const Color _dOliveDk    = Color(0xFF9CAC68);
  static const Color _dGreenPale  = Color(0xFF143125); // GREEN 4 (success bg)

  static const Color _dText1      = Color(0xFFF2E1CA); // heading
  static const Color _dText2      = Color(0xFFDBB594); // body
  static const Color _dText3      = Color(0xFFBD926C); // meta/hint

  static const Color _dInputBord  = Color(0xFF614C3A); // BROWN 7
  static const Color _dDivGreen   = Color(0xFF48392D); // BROWN 6
  static const Color _dInputBg    = Color(0xFF29221D); // BROWN 3 (lifted)

  // Public palette — mode-aware getters.

  static Color get cream      => _isDark ? _dCream     : _lCream;
  static Color get creamMid   => _isDark ? _dCreamMid  : _lCreamMid;
  static Color get creamDark  => _isDark ? _dCreamDark : _lCreamDark;
  static Color get creamWarm  => _isDark ? _dCreamWarm : _lCreamWarm;

  static Color get pinkPop        => _isDark ? _dPinkPop    : _lPinkPop;
  static Color get pinkSoft       => _isDark ? _dPinkSoft   : _lPinkSoft;
  static Color get pinkDark       => _isDark ? _dPinkDark   : _lPinkDark;
  static Color get pinkAccent     => _isDark ? _dPinkAcc    : _lPinkAcc;
  static Color get pinkAccentDeep => _isDark ? _dPinkAccDp  : _lPinkAccDp;
  static Color get pinkLight      => _isDark ? _dPinkLight  : _lPinkLight;

  static Color get coral     => _isDark ? _dCoral     : _lCoral;
  static Color get coralDark => _isDark ? _dCoralDark : _lCoralDark;
  static Color get coralSoft => _isDark ? _dCoralSoft : _lCoralSoft;

  static Color get sage      => _isDark ? _dSage     : _lSage;
  static Color get sageDark  => _isDark ? _dSageDark : _lSageDark;

  static Color get gold       => _isDark ? _dGold       : _lGold;
  static Color get goldDark   => _isDark ? _dGoldDark   : _lGoldDark;
  static Color get orangeWarm => _isDark ? _dOrangeWarm : _lOrangeWarm;

  static Color get sky       => _isDark ? _dSky       : _lSky;
  static Color get skyDark   => _isDark ? _dSkyDark   : _lSkyDark;
  static Color get blueLight => _isDark ? _dBlueLight : _lBlueLight;

  static Color get lavender     => _isDark ? _dLav     : _lLav;
  static Color get lavenderDark => _isDark ? _dLavDark : _lLavDark;

  static Color get outline    => _isDark ? _dOutline  : _lOutline;
  static Color get brown      => _isDark ? _dBrown    : _lBrown;
  static Color get brownDark  => _isDark ? _dBrownDk  : _lBrownDk;
  static Color get shadow     => _isDark ? _dShadow   : _lShadow;
  static Color get shadowDark => _isDark ? _dShadowDk : _lShadowDk;

  static Color get olive       => _isDark ? _dOlive      : _lOlive;
  static Color get oliveDark   => _isDark ? _dOliveDk    : _lOliveDk;
  static Color get greenPale   => _isDark ? _dGreenPale  : _lGreenPale;
  static Color get text1       => _isDark ? _dText1      : _lText1;
  static Color get text2       => _isDark ? _dText2      : _lText2;
  static Color get text3       => _isDark ? _dText3      : _lText3;
  static Color get inputBorder => _isDark ? _dInputBord  : _lInputBord;
  static Color get dividerGreen=> _isDark ? _dDivGreen   : _lDivGreen;
  static Color get inputBg     => _isDark ? _dInputBg    : _lInputBg;

  static Color get primaryPurple => lavender;
  static Color get primaryBlue   => sky;
  static Color get accentGreen   => sage;
  static Color get accentOrange  => gold;
  static Color get accentRed     => coral;
  static Color get xpGold        => gold;

  //  DECORATION HELPERS (now mode-aware via getters above)
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

  /// Card decoration with mode-aware default surface color.
  static BoxDecoration cuteCard({
    Color? color,
    double radius = 20,
    bool large = false,
  }) {
    return BoxDecoration(
      color: color ?? (_isDark ? _dCreamMid : Colors.white),
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

  // Light theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _lCream,
      colorScheme: const ColorScheme.light(
        primary: _lPinkPop,
        secondary: _lSage,
        tertiary: _lLav,
        surface: _lCream,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _lOutline,
        outline: _lOutline,
      ),

      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: _lOutline),
        displayMedium: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: _lOutline),
        headlineLarge: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: _lOutline),
        headlineMedium: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: _lOutline),
        titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: _lOutline),
        titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: _lOutline),
        bodyLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: _lOutline),
        bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: _lOutline),
        bodySmall: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _lBrown),
        labelLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: _lOutline,
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _lOutline, width: 4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: _lPinkPop,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _lOutline, width: 4),
          ),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: _lOutline, width: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lOutline, width: 3)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lOutline, width: 3)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lPinkPop, width: 3)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lCoral, width: 3)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _lCoral, width: 3)),
        hintStyle: const TextStyle(color: _lCreamDark, fontWeight: FontWeight.w600),
        labelStyle: const TextStyle(color: _lOutline, fontWeight: FontWeight.w700, fontSize: 14),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: _lPinkSoft.withOpacity(0.3),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: _lPinkPop);
          }
          return GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _lBrown);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _lPinkPop, size: 26);
          }
          return const IconThemeData(color: _lBrown, size: 24);
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _lPinkPop,
        unselectedItemColor: _lBrown,
        showUnselectedLabels: true,
      ),
    );
  }

  // Dark theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _dCream,
      colorScheme: const ColorScheme.dark(
        primary: _dPinkPop,
        secondary: _dSage,
        tertiary: _dLav,
        surface: _dCreamMid,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: _dOutline,
        outline: _dOutline,
      ),

      fontFamily: GoogleFonts.nunito().fontFamily,
      textTheme: TextTheme(
        displayLarge: GoogleFonts.nunito(fontSize: 32, fontWeight: FontWeight.w800, color: _dOutline),
        displayMedium: GoogleFonts.nunito(fontSize: 28, fontWeight: FontWeight.w800, color: _dOutline),
        headlineLarge: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w800, color: _dOutline),
        headlineMedium: GoogleFonts.nunito(fontSize: 20, fontWeight: FontWeight.w700, color: _dOutline),
        titleLarge: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w700, color: _dOutline),
        titleMedium: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600, color: _dOutline),
        bodyLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w600, color: _dOutline),
        bodyMedium: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: _dOutline),
        bodySmall: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _dBrown),
        labelLarge: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
      ),

      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: _dOutline,
      ),

      cardTheme: CardThemeData(
        color: _dCreamMid,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: _dOutline, width: 4),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          backgroundColor: _dPinkPop,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: _dOutline, width: 4),
          ),
          textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w800),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: const BorderSide(color: _dOutline, width: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _dCreamMid,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dOutline, width: 3)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dOutline, width: 3)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dPinkPop, width: 3)),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dCoral, width: 3)),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _dCoral, width: 3)),
        hintStyle: const TextStyle(color: _dBrown, fontWeight: FontWeight.w600),
        labelStyle: const TextStyle(color: _dOutline, fontWeight: FontWeight.w700, fontSize: 14),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _dCreamMid,
        indicatorColor: _dPinkSoft.withOpacity(0.3),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w800, color: _dPinkPop);
          }
          return GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _dBrown);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _dPinkPop, size: 26);
          }
          return const IconThemeData(color: _dBrown, size: 24);
        }),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: _dPinkPop,
        unselectedItemColor: _dBrown,
        showUnselectedLabels: true,
      ),
    );
  }
}
