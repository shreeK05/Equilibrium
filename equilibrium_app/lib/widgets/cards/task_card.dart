import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../status/status_badge.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String? subject;
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
    this.subject,
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
        borderRadius: EqTokens.border24,
        border: Border.all(
          color: isCompleted ? Colors.transparent : colors.surfaceElevated.withValues(alpha: 0.5),
        ),
        boxShadow: isCompleted ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
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
                          if (subject != null || category != null) ...[
                            Row(
                              children: [
                                if (subject != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: colors.primary.withValues(alpha: 0.1),
                                      borderRadius: EqTokens.border8,
                                    ),
                                    child: Text(
                                      subject!.toUpperCase(),
                                      style: text.labelSmall?.copyWith(
                                        color: colors.primary,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                if (subject != null && category != null) const SizedBox(width: 8),
                                if (category != null)
                                  Text(
                                    category!.toUpperCase(),
                                    style: text.labelSmall?.copyWith(
                                      color: colors.textSecondary,
                                      letterSpacing: 0.5,
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
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: colors.textSecondary),
                    const SizedBox(width: EqTokens.space4),
                    Text(
                      durationStr,
                      style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                    ),
                    const SizedBox(width: EqTokens.space16),
                    Icon(
                      isFlexible ? Icons.event_available : Icons.event,
                      size: 16,
                      color: isFlexible ? colors.primary : colors.textSecondary,
                    ),
                    const SizedBox(width: EqTokens.space4),
                    Text(
                      deadlineStr,
                      style: text.bodyMedium?.copyWith(
                        color: isFlexible ? colors.primary : colors.textSecondary,
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
