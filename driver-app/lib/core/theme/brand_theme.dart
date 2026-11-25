import 'package:flutter/material.dart';

/// Shared VeloFleet color tokens exposed cleanly in both Light & Night-Driving themes.
@immutable
class BrandThemeExtension extends ThemeExtension<BrandThemeExtension> {
  const BrandThemeExtension({
    required this.primary,
    required this.accent,
    required this.success,
    required this.warning,
    required this.danger,
    required this.surfaceMuted,
  });

  final Color primary;
  final Color accent;
  final Color success;
  final Color warning;
  final Color danger;
  final Color surfaceMuted;

  @override
  BrandThemeExtension copyWith({
    Color? primary,
    Color? accent,
    Color? success,
    Color? warning,
    Color? danger,
    Color? surfaceMuted,
  }) => BrandThemeExtension(
    primary: primary ?? this.primary,
    accent: accent ?? this.accent,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    danger: danger ?? this.danger,
    surfaceMuted: surfaceMuted ?? this.surfaceMuted,
  );

  @override
  BrandThemeExtension lerp(ThemeExtension<BrandThemeExtension>? other, double t) {
    if (other is! BrandThemeExtension) return this;
    return BrandThemeExtension(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      success: Color.lerp(success, other.success, t) ?? success,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      surfaceMuted: Color.lerp(surfaceMuted, other.surfaceMuted, t) ?? surfaceMuted,
    );
  }
}

/// High-contrast daylight and low-glare night-driving themes.
class DriverBrandTheme {
  const DriverBrandTheme._();

  static const _brand = BrandThemeExtension(
    primary: Color(0xFF0F3D5E),
    accent: Color(0xFF0EA5E9),
    success: Color(0xFF15803D),
    warning: Color(0xFFB45309),
    danger: Color(0xFFB91C1C),
    surfaceMuted: Color(0xFFF1F5F9),
  );

  static const _brandDark = BrandThemeExtension(
    primary: Color(0xFF38BDF8),
    accent: Color(0xFF0EA5E9),
    success: Color(0xFF22C55E),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    surfaceMuted: Color(0xFF1E293B),
  );

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF0F3D5E),
      brightness: Brightness.light,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(88, 54)),
    ),
    extensions: const [_brand],
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0B1220),
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF38BDF8),
      brightness: Brightness.dark,
      surface: const Color(0xFF162033),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF162033),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(88, 54)),
    ),
    extensions: const [_brandDark],
  );
}
