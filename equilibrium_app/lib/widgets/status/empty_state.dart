import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(EqTokens.space32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: colors.surfaceElevated),
            const SizedBox(height: EqTokens.space24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: text.titleLarge?.copyWith(color: colors.textPrimary),
            ),
            const SizedBox(height: EqTokens.space8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: EqTokens.space32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                onPressed: onAction,
                child: Text(actionLabel!, style: text.labelLarge?.copyWith(color: colors.surface)),
              )
            ]
          ],
        ),
      ),
    );
  }
}
