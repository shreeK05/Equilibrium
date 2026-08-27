import 'package:flutter/material.dart';

class EqColors extends ThemeExtension<EqColors> {
  final Color primary;
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color textPrimary;
  final Color textSecondary;
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
    required this.textPrimary,
    required this.textSecondary,
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
    primary: Color(0xFF1E293B), // Deep Slate
    background: Color(0xFFF8FAFC), // Off-white
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1F5F9),
    textPrimary: Color(0xFF0F172A),
    textSecondary: Color(0xFF64748B),
    success: Color(0xFF10B981), // Emerald
    warning: Color(0xFFF59E0B), // Amber
    danger: Color(0xFFEF4444),  // Red
    sleepShield: Color(0xFF6366F1), // Indigo
    sleepShieldMuted: Color(0xFFEEF2FF),
    workload: Color(0xFF3B82F6), // Blue
    energyPeak: Color(0xFF8B5CF6), // Violet
    energyHigh: Color(0xFF6366F1),
    energyMedium: Color(0xFF38BDF8),
    energyLow: Color(0xFF94A3B8),
    statusDeferred: Color(0xFFF59E0B),
    statusCompleted: Color(0xFF10B981),
  );

  static const dark = EqColors(
    primary: Color(0xFFE2E8F0),
    background: Color(0xFF0B0F19), // Very dark slate/blue
    surface: Color(0xFF161E2E), // Card background
    surfaceElevated: Color(0xFF1E293B),
    textPrimary: Color(0xFFF8FAFC),
    textSecondary: Color(0xFF94A3B8),
    success: Color(0xFF10B981),
    warning: Color(0xFFF59E0B),
    danger: Color(0xFFEF4444),
    sleepShield: Color(0xFF818CF8), // Lighter Indigo for dark mode
    sleepShieldMuted: Color(0xFF1E1B4B),
    workload: Color(0xFF60A5FA),
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
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
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
