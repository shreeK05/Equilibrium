import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/timeline/timeline.dart';
import '../../widgets/status/loading_skeleton.dart';
import '../../widgets/status/empty_state.dart';
import '../../widgets/status/error_state.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/utils/workload_calculator.dart';
import '../../widgets/status/workload_meter.dart' as equilibrium_app_workload;
import '../../widgets/status/change_summary.dart';
import 'weekly_schedule_screen.dart';
import '../../widgets/dialogs/conversational_reschedule_dialog.dart';

import 'package:intl/intl.dart';
import '../../models/decision_log.dart';
import '../../models/task.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Schedule Timeline'),
        backgroundColor: colors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.forum_outlined),
            tooltip: 'Conversational Reschedule',
            onPressed: () => ConversationalRescheduleDialog.show(context),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_view_week),
            tooltip: '7-Day Overview',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const WeeklyScheduleScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentSchedule == null) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EquilibriumLoadingState(),
                const SizedBox(height: EqTokens.space16),
                Text(
                  'Preparing your day...\nFinding available time...\nBalancing workload...',
                  textAlign: TextAlign.center,
                  style: context.eqText.bodyMedium?.copyWith(
                    color: context.eqColors.textSecondary,
                  ),
                ).animate().fade().slideY(begin: 0.2),
              ],
            );
          }

          if (provider.errorMessage != null && provider.currentSchedule == null) {
            return ErrorStateWidget(
              title: 'Schedule unavailable',
              message: provider.errorMessage!,
              onRetry: provider.fetchDashboardData,
            ).animate().fade().scale(begin: const Offset(0.95, 0.95));
          }

          final schedule = provider.currentSchedule;
          
          if (schedule == null) {
            return EmptyStateWidget(
              title: 'No schedule generated yet.',
              message: 'Add tasks and let Equilibrium balance your workload.',
              icon: Icons.auto_awesome,
              actionLabel: 'Generate Schedule',
              onAction: provider.generateSchedule,
            ).animate().fade().scale(begin: const Offset(0.95, 0.95));
          }

          final sleepStart = provider.constraints?['sleepStart'] as String? ?? '23:00';
          final sleepEnd = provider.constraints?['sleepEnd'] as String? ?? '07:00';
          final bufferMinutes = provider.constraints?['bufferMinutes'] as int? ?? 15;

          final workload = WorkloadCalculator.calculateCapacity(
            date: provider.selectedDate,
            sleepStart: sleepStart,
            sleepEnd: sleepEnd,
            commitments: provider.commitments,
            bufferMinutes: bufferMinutes,
            blocks: schedule.blocks,
          );

          final plannedMinutes = workload.plannedMinutes;
          final availableMinutes = workload.availableCapacityMinutes;

          return Column(
            children: [
              if (provider.previousSchedule != null)
                ChangeSummaryBanner(
                  currentSchedule: schedule,
                  previousSchedule: provider.previousSchedule,
                  onDismiss: provider.clearChangeSummary,
                ).animate().fade().slideY(begin: -0.1),
              _buildDateNavigator(context, provider),
              if (schedule.decisionLogs.any((d) => d.decisionType == DecisionType.deferred)) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space4),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(EqTokens.space12),
                    decoration: BoxDecoration(
                      color: colors.warning.withValues(alpha: 0.08),
                      borderRadius: EqTokens.border12,
                      border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: colors.warning),
                            const SizedBox(width: EqTokens.space8),
                            Text(
                              'Unscheduled Tasks (${schedule.decisionLogs.where((d) => d.decisionType == DecisionType.deferred).length})',
                              style: text.labelMedium?.copyWith(
                                color: colors.warning,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: EqTokens.space6),
                        ...schedule.decisionLogs.where((d) => d.decisionType == DecisionType.deferred).map((log) {
                          final task = provider.activeTasks.cast<Task?>().firstWhere(
                            (t) => t?.id == log.taskId,
                            orElse: () => null,
                          );
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '• ${task?.title ?? 'Task'}: ${log.humanReadable}',
                              style: text.bodySmall?.copyWith(color: colors.textPrimary),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: EqTokens.border12,
                    border: Border.all(color: colors.cardBorder),
                  ),
                  child: equilibrium_app_workload.WorkloadMeter(
                    plannedMinutes: plannedMinutes,
                    availableMinutes: availableMinutes,
                  ),
                ),
              ).animate().fade(delay: 100.ms),
              Expanded(
                child: GestureDetector(
                  onHorizontalDragEnd: (details) {
                    final velocity = details.primaryVelocity ?? 0;
                    if (velocity > 300) {
                      // Swipe right -> previous day
                      provider.setSelectedDate(provider.selectedDate.subtract(const Duration(days: 1)));
                    } else if (velocity < -300) {
                      // Swipe left -> next day
                      provider.setSelectedDate(provider.selectedDate.add(const Duration(days: 1)));
                    }
                  },
                  child: ScheduleTimeline(
                    schedule: schedule,
                    tasks: provider.activeTasks,
                    commitments: provider.commitments,
                    constraints: provider.constraints,
                    selectedDate: provider.selectedDate,
                  ).animate().fade(delay: 200.ms),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<ScheduleProvider>(
        builder: (context, provider, child) {
          final schedule = provider.currentSchedule;
          if (schedule == null || provider.isLoading) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            heroTag: 'fab_reschedule',
            onPressed: () => provider.reschedule(),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Reschedule'),
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ).animate().scale(delay: 500.ms, duration: 300.ms, curve: Curves.easeOutBack);
        },
      ),
    );
  }

  Widget _buildDateNavigator(BuildContext context, ScheduleProvider provider) {
    final colors = context.eqColors;
    final selected = provider.selectedDate;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final isToday = selected.year == today.year && selected.month == today.month && selected.day == today.day;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.cardBorder)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colors.textPrimary),
            tooltip: 'Previous Day',
            onPressed: () => provider.setSelectedDate(selected.subtract(const Duration(days: 1))),
          ),
          Column(
            children: [
              Text(
                isToday ? 'TODAY' : DateFormat('E, d MMM').format(selected).toUpperCase(),
                style: context.eqText.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(
                height: 20,
                child: !isToday
                  ? GestureDetector(
                      onTap: () => provider.setSelectedDate(today),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Back to Today',
                          style: context.eqText.labelMedium?.copyWith(
                            color: colors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
              ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: colors.textPrimary),
            tooltip: 'Next Day',
            onPressed: () => provider.setSelectedDate(selected.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}
