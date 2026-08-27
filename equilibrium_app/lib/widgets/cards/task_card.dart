import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../status/status_badge.dart';

class TaskCard extends StatelessWidget {
  final String title;
  final String subject;
  final String durationStr;
  final String deadlineStr;
  final EqStatus status;

  const TaskCard({
    super.key,
    required this.title,
    required this.subject,
    required this.durationStr,
    required this.deadlineStr,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: EqTokens.border12,
        border: Border.all(color: colors.surfaceElevated),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
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
                    Text(
                      subject.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: EqTokens.space4),
                    Text(
                      title,
                      style: text.titleLarge?.copyWith(
                        color: colors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: EqTokens.space16),
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 16, color: colors.textSecondary),
              const SizedBox(width: EqTokens.space4),
              Text(
                durationStr,
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(width: EqTokens.space16),
              Icon(Icons.event_outlined, size: 16, color: colors.textSecondary),
              const SizedBox(width: EqTokens.space4),
              Text(
                deadlineStr,
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
            ],
          )
        ],
      ),
    );
  }
}
