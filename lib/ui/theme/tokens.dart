// Design tokens for "Stock" — WhatsApp-style UI (locked spec): teal header,
// underline fields, pill uppercase buttons, colored accent bars.
//
// AppColors fields are getters (not const) that branch on
// ThemeController.instance.isDark, so every screen automatically repaints
// for the current light/dark mode without needing BuildContext threading.
// This means color values can no longer be used in `const` expressions —
// `flutter analyze` will flag every spot that still needs its `const`
// keyword removed after editing a color here.
import 'package:flutter/material.dart';

import 'theme_controller.dart';

class AppColors {
  AppColors._();

  static bool get _dark => ThemeController.instance.isDark;

  static Color get primary =>
      const Color(0xFF075E54); // app bar / header — same in both modes
  static Color get headerSubtitle =>
      const Color(0xFFCFEDE8); // header subtitle text
  static Color get accent => const Color(0xFF25D366); // FAB, positive accents

  static Color get background =>
      _dark ? const Color(0xFF0B141A) : const Color(0xFFF6F6F6);
  static Color get surface =>
      _dark ? const Color(0xFF202C33) : const Color(0xFFFFFFFF);
  static Color get divider =>
      _dark ? const Color(0xFF2A3942) : const Color(0xFFE3E3E3);

  static Color get textPrimary =>
      _dark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
  static Color get textSecondary =>
      _dark ? const Color(0xFFAEBAC1) : const Color(0xFF667781);
  static Color get inactiveIcon =>
      _dark ? const Color(0xFF8696A0) : const Color(0xFF8696A0);

  static Color get negative =>
      _dark ? const Color(0xFFFF6B6B) : const Color(0xFFD32F2F);

  // Left accent bars + primary color per entry type.
  static Color get purchaseColor =>
      _dark ? const Color(0xFF25B89A) : const Color(0xFF128C7E);
  static Color get saleColor =>
      _dark ? const Color(0xFFF08C1A) : const Color(0xFFDC6803);
  // Diesel: its own blue, distinct from purchase (teal) and sale (orange).
  static Color get dieselColor =>
      _dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0);

  // Profit highlight chip (positive).
  static Color get profitPositiveBg =>
      _dark ? const Color(0xFF0F3D2E) : const Color(0xFFDCF8C6);
  static Color get profitPositiveText =>
      _dark ? const Color(0xFF4ADE80) : const Color(0xFF075E54);
  // Profit highlight chip (negative).
  static Color get profitNegativeBg =>
      _dark ? const Color(0xFF3D1515) : const Color(0xFFFADBD8);
  static Color get profitNegativeText =>
      _dark ? const Color(0xFFFF6B6B) : const Color(0xFFC0392B);
  // Sale highlight chip.
  static Color get saleHighlightBg =>
      _dark ? const Color(0xFF3D2A0F) : const Color(0xFFFDEBD3);
  static Color get saleHighlightText =>
      _dark ? const Color(0xFFFFB74D) : const Color(0xFF9A5B12);

  // Fixed 5-color rotation for letter avatars (brands/parties).
  static List<Color> get avatarBg => _dark
      ? const [
          Color(0xFF123524), // mint
          Color(0xFF0F2A42), // blue
          Color(0xFF3D2E12), // tan
          Color(0xFF2A1F42), // purple
          Color(0xFF3D1F2C), // pink
        ]
      : const [
          Color(0xFFDCF2E3), // mint
          Color(0xFFD7E6F5), // blue
          Color(0xFFF5E8D3), // tan
          Color(0xFFE6E0F5), // purple
          Color(0xFFF7DFE6), // pink
        ];
  static List<Color> get avatarFg => _dark
      ? const [
          Color(0xFF4ADE80),
          Color(0xFF64B5F6),
          Color(0xFFFFCA28),
          Color(0xFFB39DDB),
          Color(0xFFF48FB1),
        ]
      : const [
          Color(0xFF1D7A4C),
          Color(0xFF2B6CA3),
          Color(0xFF9C6B23),
          Color(0xFF6A4FA0),
          Color(0xFFB3467C),
        ];
}

class AppRadii {
  AppRadii._();
  static const card = 14.0;
  static const pill = 24.0;
}

class AppSpacing {
  AppSpacing._();
  static const cardGap = 12.0;
  static const sectionGap = 16.0;
  static const screenPadding = 16.0;
}

/// Text/icon color for a given metric type — profit flips green/red;
/// purchase/sale stay fixed. Cards themselves are plain white/dark-surface.
class MetricPalette {
  final Color color;
  final Color highlightBg;
  final Color highlightText;
  const MetricPalette(this.color, this.highlightBg, this.highlightText);

  static MetricPalette get profit => MetricPalette(
    AppColors.accent,
    AppColors.profitPositiveBg,
    AppColors.profitPositiveText,
  );
  static MetricPalette get profitNegative => MetricPalette(
    AppColors.negative,
    AppColors.profitNegativeBg,
    AppColors.profitNegativeText,
  );
  static MetricPalette get purchase => MetricPalette(
    AppColors.purchaseColor,
    AppColors.profitPositiveBg,
    AppColors.profitPositiveText,
  );
  static MetricPalette get sale => MetricPalette(
    AppColors.saleColor,
    AppColors.saleHighlightBg,
    AppColors.saleHighlightText,
  );
}

/// Deterministic avatar color pair for a name — same name always gets the
/// same color, spread across the fixed 5-color rotation.
(Color bg, Color fg) avatarColorsFor(String name) {
  final i = name.isEmpty ? 0 : name.codeUnitAt(0) % AppColors.avatarBg.length;
  return (AppColors.avatarBg[i], AppColors.avatarFg[i]);
}

ThemeData buildAppTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: AppColors.primary,
    brightness: ThemeController.instance.isDark
        ? Brightness.dark
        : Brightness.light,
  );
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    ),
    // Underline fields — no fill, just a bottom rule; label sits above the
    // value in small uppercase gray text, matching the locked mockups.
    inputDecorationTheme: InputDecorationTheme(
      filled: false,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
      labelStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      floatingLabelStyle: TextStyle(
        color: AppColors.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      floatingLabelBehavior: FloatingLabelBehavior.always,
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider, width: 1),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.divider, width: 1),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.negative, width: 1),
      ),
      focusedErrorBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.negative, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: BorderSide(color: AppColors.primary),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
        shape: const StadiumBorder(),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.card),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: AppColors.divider,
      thickness: 1,
      space: 1,
    ),
  );
}
