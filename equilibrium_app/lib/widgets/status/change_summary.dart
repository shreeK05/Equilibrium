import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/schedule.dart';
import '../../models/decision_log.dart';

class ChangeSummaryBanner extends StatelessWidget {
  final ScheduleVersion currentSchedule;
  final ScheduleVersion? previousSchedule;
  final VoidCallback onDismiss;

  const ChangeSummaryBanner({
    super.key,
    required this.currentSchedule,
    this.previousSchedule,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    if (previousSchedule == null || currentSchedule.previousVersionId != previousSchedule!.id) {
      return const SizedBox.shrink(); // No relevant previous schedule to compare
    }

    final colors = context.eqColors;
    final text = context.eqText;

    // Calculate metrics deterministically based on actual backend data
    int movedCount = 0;
    
    // Determine moved tasks
    final oldTasks = <String, DateTime>{};
    for (var b in previousSchedule!.blocks) {
      if (b.type == 'TASK' && b.taskId != null) {
        if (!oldTasks.containsKey(b.taskId) || b.startTime.isBefore(oldTasks[b.taskId]!)) {
          oldTasks[b.taskId!] = b.startTime;
        }
      }
    }

    final newTasks = <String, DateTime>{};
    for (var b in currentSchedule.blocks) {
      if (b.type == 'TASK' && b.taskId != null) {
        if (!newTasks.containsKey(b.taskId) || b.startTime.isBefore(newTasks[b.taskId]!)) {
          newTasks[b.taskId!] = b.startTime;
        }
      }
    }

    newTasks.forEach((taskId, newStart) {
      if (oldTasks.containsKey(taskId)) {
        final oldStart = oldTasks[taskId]!;
        if (newStart.isAtSameMomentAs(oldStart) == false) {
          movedCount++;
        }
      }
    });

    // Determine deferred and partial based on DecisionLogs
    int deferredCount = 0;
    int partialCount = 0;

    for (var log in currentSchedule.decisionLogs) {
      if (log.decisionType == DecisionType.deferred) deferredCount++;
      if (log.decisionType == DecisionType.partiallyScheduled) partialCount++;
    }

    if (movedCount == 0 && deferredCount == 0 && partialCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.05),
        border: Border.all(color: colors.primary.withOpacity(0.2)),
        borderRadius: EqTokens.border8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_mode, color: colors.primary, size: 20),
                  const SizedBox(width: EqTokens.space8),
                  Text(
                    'Schedule Updated',
                    style: text.labelLarge?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: onDismiss,
                child: Icon(Icons.close, color: colors.textSecondary, size: 20),
              ),
            ],
          ),
          const SizedBox(height: EqTokens.space12),
          if (movedCount > 0) _buildStatRow(context, Icons.swap_vert, '$movedCount task${movedCount == 1 ? '' : 's'} moved'),
          if (partialCount > 0) _buildStatRow(context, Icons.pie_chart_outline, '$partialCount task${partialCount == 1 ? '' : 's'} partially scheduled'),
          if (deferredCount > 0) _buildStatRow(context, Icons.event_busy, '$deferredCount task${deferredCount == 1 ? '' : 's'} deferred'),
        ],
      ),
    );
  }

  Widget _buildStatRow(BuildContext context, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: context.eqColors.textPrimary),
          const SizedBox(width: EqTokens.space8),
          Text(
            label,
            style: context.eqText.bodyMedium?.copyWith(color: context.eqColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
