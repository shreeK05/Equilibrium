import 'package:flutter/material.dart';

class EqColors extends ThemeExtension<EqColors> {
  final Color primary;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceSubtle;
  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color cardBorder;
  final Color commitment;
  final Color commitmentMuted;
  final Color success;
  final Color warning;
  final Color danger;
  final Color sleepShield;
  final Color sleepShieldMuted;
  final Color workload;
  final Color energyPeak;
  final Color energyHigh;
  final Color energyMedium;
  final Color energyLow;
  final Color statusDeferred;
  final Color statusCompleted;

  const EqColors({
    required this.primary,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceSubtle,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.cardBorder,
    required this.commitment,
    required this.commitmentMuted,
    required this.success,
    required this.warning,
    required this.danger,
    required this.sleepShield,
    required this.sleepShieldMuted,
    required this.workload,
    required this.energyPeak,
    required this.energyHigh,
    required this.energyMedium,
    required this.energyLow,
    required this.statusDeferred,
    required this.statusCompleted,
  });

  static const light = EqColors(
    primary: Color(0xFF4F46E5), // Indigo 600 - High contrast & accessible
    background: Color(0xFFF8FAFC), // Slate 50
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9), // Slate 100
    surfaceSubtle: Color(0xFFF8FAFC),
    textPrimary: Color(0xFF0F172A), // Slate 900
    textSecondary: Color(0xFF475569), // Slate 600 (contrast > 7:1)
    textTertiary: Color(0xFF64748B), // Slate 500 (contrast > 4.5:1)
    cardBorder: Color(0xFFE2E8F0), // Slate 200
    commitment: Color(0xFF0284C7), // Sky 600 - Distinct from tasks & sleep
    commitmentMuted: Color(0xFFF0F9FF), // Sky 50
    success: Color(0xFF059669), // Emerald 600
    warning: Color(0xFFD97706), // Amber 600
    danger: Color(0xFFDC2626),  // Red 600
    sleepShield: Color(0xFF4338CA), // Deep Indigo 700
    sleepShieldMuted: Color(0xFFEEF2FF), // Indigo 50
    workload: Color(0xFF2563EB), // Blue 600
    energyPeak: Color(0xFF7C3AED), // Violet 600
    energyHigh: Color(0xFF4F46E5),
    energyMedium: Color(0xFF0284C7),
    energyLow: Color(0xFF64748B),
    statusDeferred: Color(0xFFD97706),
    statusCompleted: Color(0xFF059669),
  );

  static const dark = EqColors(
    primary: Color(0xFF818CF8), // Soft Indigo for dark
    background: Color(0xFF0B0F19), // Deep calm slate
    surface: Color(0xFF161E2E), // Slate surface
    surfaceElevated: Color(0xFF222F44), // Slate elevated
    surfaceSubtle: Color(0xFF1A2333),
    textPrimary: Color(0xFFF8FAFC), // Slate 50
    textSecondary: Color(0xFF94A3B8), // Slate 400 (contrast > 5:1)
    textTertiary: Color(0xFF64748B), // Slate 500
    cardBorder: Color(0xFF263347), // Subtle card border
    commitment: Color(0xFF38BDF8), // Sky 400 - Distinct from tasks
    commitmentMuted: Color(0xFF0C243B), // Sky 950
    success: Color(0xFF34D399), // Emerald 400
    warning: Color(0xFFFBBF24), // Amber 400
    danger: Color(0xFFF87171), // Red 400
    sleepShield: Color(0xFF818CF8), // Indigo
    sleepShieldMuted: Color(0xFF1E1B4B), // Deep night indigo
    workload: Color(0xFF60A5FA), // Blue 400
    energyPeak: Color(0xFFA78BFA),
    energyHigh: Color(0xFF818CF8),
    energyMedium: Color(0xFF7DD3FC),
    energyLow: Color(0xFF475569),
    statusDeferred: Color(0xFFFBBF24),
    statusCompleted: Color(0xFF34D399),
  );

  @override
  ThemeExtension<EqColors> copyWith() => this;

  @override
  ThemeExtension<EqColors> lerp(ThemeExtension<EqColors>? other, double t) {
    if (other is! EqColors) return this;
    return EqColors(
      primary: Color.lerp(primary, other.primary, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceElevated: Color.lerp(surfaceElevated, other.surfaceElevated, t)!,
      surfaceSubtle: Color.lerp(surfaceSubtle, other.surfaceSubtle, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      commitment: Color.lerp(commitment, other.commitment, t)!,
      commitmentMuted: Color.lerp(commitmentMuted, other.commitmentMuted, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      sleepShield: Color.lerp(sleepShield, other.sleepShield, t)!,
      sleepShieldMuted: Color.lerp(sleepShieldMuted, other.sleepShieldMuted, t)!,
      workload: Color.lerp(workload, other.workload, t)!,
      energyPeak: Color.lerp(energyPeak, other.energyPeak, t)!,
      energyHigh: Color.lerp(energyHigh, other.energyHigh, t)!,
      energyMedium: Color.lerp(energyMedium, other.energyMedium, t)!,
      energyLow: Color.lerp(energyLow, other.energyLow, t)!,
      statusDeferred: Color.lerp(statusDeferred, other.statusDeferred, t)!,
      statusCompleted: Color.lerp(statusCompleted, other.statusCompleted, t)!,
    );
  }
}
