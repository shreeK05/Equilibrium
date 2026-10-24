import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../status/status_badge.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String? category;
  final String durationStr;
  final String deadlineStr;
  final bool isFlexible;
  final EqStatus status;
  final VoidCallback? onComplete;
  final VoidCallback? onStartTimer;
  final bool isCompleted;

  const TaskCard({
    super.key,
    required this.title,
    this.category,
    required this.durationStr,
    required this.deadlineStr,
    this.isFlexible = false,
    required this.status,
    this.onComplete,
    this.onStartTimer,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: isCompleted ? colors.surfaceElevated : colors.surface,
        borderRadius: EqTokens.border16,
        border: Border.all(
          color: isCompleted ? Colors.transparent : colors.cardBorder,
        ),
        boxShadow: isCompleted ? [] : EqTokens.shadowSubtle,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Animated Checkbox
          GestureDetector(
            onTap: onComplete,
            child: Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(top: 2, right: EqTokens.space12),
              decoration: BoxDecoration(
                color: isCompleted ? colors.success : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isCompleted ? colors.success : colors.textSecondary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child: isCompleted
                  ? Icon(Icons.check, size: 16, color: colors.surface)
                  : null,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (category != null) ...[
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                              children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Text(
                                      category!.toUpperCase(),
                                      style: text.labelSmall?.copyWith(
                                        color: colors.primary,
                                        letterSpacing: 0.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: EqTokens.space8),
                          ],
                          Text(
                            title,
                            style: text.titleLarge?.copyWith(
                              color: isCompleted ? colors.textSecondary : colors.textPrimary,
                              decoration: isCompleted ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isCompleted && onStartTimer != null)
                      IconButton(
                        icon: Icon(Icons.play_circle_fill, color: colors.primary, size: 32),
                        onPressed: onStartTimer,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: EqTokens.space16),
                Wrap(
                  spacing: EqTokens.space16,
                  runSpacing: EqTokens.space4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.schedule, size: 16, color: colors.textSecondary),
                        const SizedBox(width: EqTokens.space4),
                        Text(
                          durationStr,
                          style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFlexible ? Icons.event_available : Icons.event,
                          size: 16,
                          color: isFlexible ? colors.primary : colors.textSecondary,
                        ),
                        const SizedBox(width: EqTokens.space4),
                        Flexible(
                          child: Text(
                            deadlineStr,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium?.copyWith(
                              color: isFlexible ? colors.primary : colors.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
