import 'package:flutter/material.dart';

/// Shared VeloFleet color tokens implementing shared-contracts/design-tokens.md.
class BrandTokens extends ThemeExtension<BrandTokens> {
  const BrandTokens({
    required this.primary700,
    required this.primary500,
    required this.primary100,
    required this.secondary600,
    required this.accent500,
    required this.canvasBg,
    required this.cardSurface,
    required this.mutedSurface,
    required this.borderSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.successFg,
    required this.successBg,
    required this.warningFg,
    required this.warningBg,
    required this.errorFg,
    required this.errorBg,
    required this.infoFg,
    required this.infoBg,
  });

  final Color primary700;
  final Color primary500;
  final Color primary100;
  final Color secondary600;
  final Color accent500;
  final Color canvasBg;
  final Color cardSurface;
  final Color mutedSurface;
  final Color borderSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color successFg;
  final Color successBg;
  final Color warningFg;
  final Color warningBg;
  final Color errorFg;
  final Color errorBg;
  final Color infoFg;
  final Color infoBg;

  static const light = BrandTokens(
    primary700: Color(0xFF0F3D7A),
    primary500: Color(0xFF1D63DC),
    primary100: Color(0xFFE8F0FE),
    secondary600: Color(0xFF0D9488),
    accent500: Color(0xFFF59E0B),
    canvasBg: Color(0xFFF8FAFC),
    cardSurface: Color(0xFFFFFFFF),
    mutedSurface: Color(0xFFF1F5F9),
    borderSubtle: Color(0xFFE2E8F0),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF475569),
    successFg: Color(0xFF047857),
    successBg: Color(0xFFD1FAE5),
    warningFg: Color(0xFFB45309),
    warningBg: Color(0xFFFEF3C7),
    errorFg: Color(0xFFB91C1C),
    errorBg: Color(0xFFFEE2E2),
    infoFg: Color(0xFF0369A1),
    infoBg: Color(0xFFE0F2FE),
  );

  @override
  BrandTokens copyWith() => this;

  @override
  BrandTokens lerp(ThemeExtension<BrandTokens>? other, double t) => this;
}

ThemeData buildAdminTheme() {
  const t = BrandTokens.light;
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: t.canvasBg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: t.primary500,
      primary: t.primary500,
      secondary: t.secondary600,
      surface: t.cardSurface,
      error: t.errorFg,
    ),
    cardTheme: CardThemeData(
      color: t.cardSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: t.borderSubtle),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: t.cardSurface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.borderSubtle),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: t.borderSubtle),
      ),
    ),
    extensions: const [t],
  );
}
