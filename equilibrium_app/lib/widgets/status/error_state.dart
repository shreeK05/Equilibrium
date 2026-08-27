import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;

  const ErrorStateWidget({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
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
            Icon(Icons.error_outline, size: 64, color: colors.danger),
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
            if (onRetry != null) ...[
              const SizedBox(height: EqTokens.space24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.surfaceElevated,
                  foregroundColor: colors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                onPressed: onRetry,
                child: const Text('Try Again'),
              )
            ]
          ],
        ),
      ),
    );
  }
}
