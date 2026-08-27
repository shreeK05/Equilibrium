import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';
import 'tokens.dart';

class EqTheme {
  static ThemeData get lightTheme {
    final colors = EqColors.light;
    return _buildTheme(Brightness.light, colors);
  }

  static ThemeData get darkTheme {
    final colors = EqColors.dark;
    return _buildTheme(Brightness.dark, colors);
  }

  static ThemeData _buildTheme(Brightness brightness, EqColors colors) {
    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
        background: colors.background,
        surface: colors.surface,
      ),
      textTheme: EqTypography.getTextTheme(brightness).apply(
        bodyColor: colors.textPrimary,
        displayColor: colors.textPrimary,
      ),
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: EqTypography.getTextTheme(brightness).titleLarge?.copyWith(
          color: colors.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        elevation: 8,
      ),
    );
  }
}

extension EqThemeContext on BuildContext {
  EqColors get eqColors => Theme.of(this).extension<EqColors>()!;
  TextTheme get eqText => Theme.of(this).textTheme;
}
