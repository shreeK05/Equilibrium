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
    final textTheme = EqTypography.getTextTheme(brightness).apply(
      bodyColor: colors.textPrimary,
      displayColor: colors.textPrimary,
    );

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      scaffoldBackgroundColor: colors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
        surface: colors.surface,
      ),
      textTheme: textTheme,
      extensions: [colors],
      appBarTheme: AppBarTheme(
        backgroundColor: colors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: colors.textPrimary),
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: colors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: colors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: EqTokens.border16,
          side: BorderSide(color: colors.cardBorder),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colors.surface,
        selectedItemColor: colors.primary,
        unselectedItemColor: colors.textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceElevated,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: EqTokens.space16,
          vertical: EqTokens.space14,
        ),
        border: OutlineInputBorder(
          borderRadius: EqTokens.border12,
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: EqTokens.border12,
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: EqTokens.border12,
          borderSide: BorderSide(color: colors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: EqTokens.border12,
          borderSide: BorderSide(color: colors.danger, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: EqTokens.border12,
          borderSide: BorderSide(color: colors.danger, width: 1.5),
        ),
        hintStyle: TextStyle(color: colors.textTertiary, fontSize: 14),
        labelStyle: TextStyle(color: colors.textSecondary, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(borderRadius: EqTokens.border12),
          padding: const EdgeInsets.symmetric(
            horizontal: EqTokens.space20,
            vertical: EqTokens.space14,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          side: BorderSide(color: colors.cardBorder),
          shape: const RoundedRectangleBorder(borderRadius: EqTokens.border12),
          padding: const EdgeInsets.symmetric(
            horizontal: EqTokens.space20,
            vertical: EqTokens.space14,
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const EdgeInsets.symmetric(
            horizontal: EqTokens.space12,
            vertical: EqTokens.space8,
          ),
          shape: const RoundedRectangleBorder(borderRadius: EqTokens.border8),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colors.surface,
        modalBackgroundColor: colors.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
        ),
        dragHandleColor: colors.textSecondary.withValues(alpha: 0.3),
        dragHandleSize: const Size(40, 4),
      ),
      dividerTheme: DividerThemeData(
        color: colors.cardBorder,
        thickness: 1,
        space: 1,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}

extension EqThemeContext on BuildContext {
  EqColors get eqColors => Theme.of(this).extension<EqColors>()!;
  TextTheme get eqText => Theme.of(this).textTheme;
}
