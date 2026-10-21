// Spotter design system ("Kinetic Monochrome" + mint accent) taken from the
// ANANA design kit (DESIGN.md + the 4 screens). Use it for EVERY screen:
//
//   MaterialApp(theme: spotterTheme(), themeMode: ThemeMode.dark, ...)
//
// Needs the `google_fonts` package (Space Grotesk, IBM Plex Sans, Cairo for Arabic).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// colour + type tokens (values read from the mockups' code.html)
class Sp {
  Sp._();

  // surfaces (dark green-black, tonal layers, no shadows)
  static const canvas = Color(0xFF0B1715); // level 0: app background
  static const card = Color(0xFF112420); // level 2: cards, chips
  static const cardHigh = Color(0xFF162F29); // level 3: dialogs, menus
  static const line = Color(0xFF1A3830); // 1px hairline borders / tracks
  static const neutral = Color(0xFF201F1F); // neutral dark (destructive button)
  static const neutralHigh = Color(0xFF2A2A2A); // icon wells

  // accent + text
  static const mint = Color(0xFF59EBAB); // primary accent / "good"
  static const mintDim = Color(0xFF83D7B1);
  static const white = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFFE5E2E1);
  static const muted = Color(0xFFC4C7C8);
  static const outline = Color(0xFF8E9192);

  // semantic status colours (only for real feedback)
  static const warn = Color(0xFFF59E0B);
  static const fault = Color(0xFFEF4444);
  static const faultSoft = Color(0xFFFFB4AB);
  static const faultContainer = Color(0xFF93000A);

  // radii
  static const rCard = 16.0;
  static const rButton = 12.0;
  static const rChip = 8.0;

  static final _ar = GoogleFonts.cairo().fontFamily!; // Arabic glyph fallback

  static TextStyle _head(double size, FontWeight w, double lsEm, double lh) =>
      GoogleFonts.spaceGrotesk(
        fontSize: size,
        fontWeight: w,
        letterSpacing: size * lsEm,
        height: lh / size,
        color: onSurface,
      ).copyWith(fontFamilyFallback: [_ar], fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle _body(double size, FontWeight w, double lh, [double ls = 0]) =>
      GoogleFonts.ibmPlexSans(
        fontSize: size,
        fontWeight: w,
        letterSpacing: ls,
        height: lh / size,
        color: onSurface,
      ).copyWith(fontFamilyFallback: [_ar]);

  static final displayMetric = _head(56, FontWeight.w700, -0.04, 60);
  static final headlineLg = _head(32, FontWeight.w700, -0.02, 38);
  static final headlineMd = _head(24, FontWeight.w600, -0.01, 30);
  static final headlineSm = _head(18, FontWeight.w600, 0, 24);
  static final bodyLg = _body(16, FontWeight.w500, 24);
  static final bodyMd = _body(14, FontWeight.w400, 20);
  static final bodySm = _body(12, FontWeight.w400, 16, 0.12);
  static final labelLg = _head(14, FontWeight.w600, 0.04, 18);
  static final labelMd = _head(12, FontWeight.w600, 0.05, 16);
  static final labelSm = _head(10, FontWeight.w700, 0.08, 14);
}

ThemeData spotterTheme() {
  const scheme = ColorScheme.dark(
    primary: Sp.mint,
    onPrimary: Sp.canvas,
    secondary: Sp.mintDim,
    onSecondary: Sp.canvas,
    error: Sp.faultSoft,
    onError: Color(0xFF690005),
    errorContainer: Sp.faultContainer,
    onErrorContainer: Color(0xFFFFDAD6),
    surface: Sp.canvas,
    onSurface: Sp.onSurface,
    onSurfaceVariant: Sp.muted,
    outline: Sp.outline,
    outlineVariant: Sp.line,
    surfaceContainerLowest: Sp.canvas,
    surfaceContainerLow: Sp.canvas,
    surfaceContainer: Sp.card,
    surfaceContainerHigh: Sp.cardHigh,
    surfaceContainerHighest: Sp.cardHigh,
  );
  RoundedRectangleBorder rr(double r, {Color side = Sp.line}) =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(r), side: BorderSide(color: side));

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Sp.canvas,
    canvasColor: Sp.canvas,
    dividerColor: Sp.line,
    iconTheme: const IconThemeData(color: Sp.onSurface),
    textTheme: TextTheme(
      displayLarge: Sp.displayMetric,
      headlineLarge: Sp.headlineLg,
      headlineMedium: Sp.headlineMd,
      headlineSmall: Sp.headlineSm,
      titleLarge: Sp.headlineSm,
      titleMedium: Sp.bodyLg,
      titleSmall: Sp.labelLg,
      bodyLarge: Sp.bodyLg,
      bodyMedium: Sp.bodyMd,
      bodySmall: Sp.bodySm,
      labelLarge: Sp.labelLg,
      labelMedium: Sp.labelMd,
      labelSmall: Sp.labelSm,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Sp.canvas,
      surfaceTintColor: Colors.transparent,
      foregroundColor: Sp.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: const Border(bottom: BorderSide(color: Sp.line)),
      titleTextStyle: Sp.headlineSm.copyWith(fontWeight: FontWeight.w700, color: Sp.white),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Sp.mint,
        foregroundColor: Sp.canvas,
        minimumSize: const Size(0, 52),
        shape: rr(Sp.rButton, side: Colors.transparent),
        textStyle: Sp.labelLg,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Sp.white,
        backgroundColor: Sp.card,
        minimumSize: const Size(0, 52),
        side: const BorderSide(color: Sp.line),
        shape: rr(Sp.rButton),
        textStyle: Sp.labelLg,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: Sp.onSurface,
        minimumSize: const Size(44, 44),
        textStyle: Sp.labelLg,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Sp.canvas,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: Sp.bodyMd.copyWith(color: Sp.muted),
      helperStyle: Sp.bodySm.copyWith(color: Sp.muted),
      errorStyle: Sp.bodySm.copyWith(color: Sp.faultSoft),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rButton), borderSide: const BorderSide(color: Sp.line)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rButton), borderSide: const BorderSide(color: Sp.line)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rButton), borderSide: const BorderSide(color: Sp.white)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rButton), borderSide: const BorderSide(color: Sp.faultSoft)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Sp.rButton), borderSide: const BorderSide(color: Sp.faultSoft)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Sp.card,
      side: const BorderSide(color: Sp.line),
      shape: rr(Sp.rChip),
      labelStyle: Sp.labelMd.copyWith(color: Sp.white),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: Sp.cardHigh,
      surfaceTintColor: Colors.transparent,
      shape: rr(Sp.rButton),
      textStyle: Sp.bodyMd,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: Sp.cardHigh,
      contentTextStyle: Sp.bodyMd,
      behavior: SnackBarBehavior.floating,
      shape: rr(Sp.rButton),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Sp.mint : Sp.card),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? Sp.canvas : Sp.white),
        side: const WidgetStatePropertyAll(BorderSide(color: Sp.line)),
        shape: WidgetStatePropertyAll(rr(Sp.rButton)),
        textStyle: WidgetStatePropertyAll(Sp.labelMd),
      ),
    ),
    // bottom tabs (Home / Workout / Nutrition / Coach / Profile)
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Sp.canvas,
      surfaceTintColor: Colors.transparent,
      indicatorColor: Colors.transparent,
      height: 64,
      labelTextStyle: WidgetStateProperty.resolveWith((s) =>
          Sp.labelSm.copyWith(color: s.contains(WidgetState.selected) ? Sp.mint : Sp.outline)),
      iconTheme: WidgetStateProperty.resolveWith((s) =>
          IconThemeData(color: s.contains(WidgetState.selected) ? Sp.mint : Sp.outline)),
    ),
  );
}
