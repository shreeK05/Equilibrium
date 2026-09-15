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
import '../../widgets/status/workload_meter.dart' as equilibrium_app_workload;
import '../../widgets/status/change_summary.dart';

import 'package:intl/intl.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    return Scaffold(
      backgroundColor: colors.background,
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

          if (!provider.hasContentForSelectedDate) {
            return Column(
              children: [
                if (provider.previousSchedule != null)
                  ChangeSummaryBanner(
                    currentSchedule: schedule,
                    previousSchedule: provider.previousSchedule,
                    onDismiss: provider.clearChangeSummary,
                  ).animate().fade().slideY(begin: -0.1),
                _buildDateNavigator(context, provider),
                const Spacer(),
                EmptyStateWidget(
                  title: 'Your workload is ready to be balanced.',
                  message: 'Not enough available time, or no tasks exist.',
                  icon: Icons.calendar_today_outlined,
                  actionLabel: 'Generate Schedule',
                  onAction: provider.generateSchedule,
                ).animate().fade().scale(begin: const Offset(0.95, 0.95)),
                const Spacer(),
              ],
            );
          }

          int plannedMinutes = 0;
          for (var t in provider.activeTasks) {
            plannedMinutes += t.remainingMinutes;
          }

          int availableMinutes = 0;
          for (var b in schedule.blocks) {
            if (b.type == 'FREE' || b.type == 'TASK') {
              availableMinutes += b.durationMinutes;
            }
          }

          return Column(
            children: [
              if (provider.previousSchedule != null)
                ChangeSummaryBanner(
                  currentSchedule: schedule,
                  previousSchedule: provider.previousSchedule,
                  onDismiss: provider.clearChangeSummary,
                ).animate().fade().slideY(begin: -0.1),
              _buildDateNavigator(context, provider),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
                child: equilibrium_app_workload.WorkloadMeter(
                  plannedMinutes: plannedMinutes,
                  availableMinutes: availableMinutes > 0 ? availableMinutes : plannedMinutes,
                ),
              ).animate().fade(delay: 100.ms),
              Expanded(
                child: ScheduleTimeline(
                  schedule: schedule,
                  tasks: provider.activeTasks,
                  commitments: provider.commitments,
                  constraints: provider.constraints,
                  selectedDate: provider.selectedDate,
                ).animate().fade(delay: 200.ms),
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
          if (!provider.hasContentForSelectedDate) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => provider.reschedule(),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Reschedule'),
            backgroundColor: colors.primary,
            foregroundColor: colors.surface,
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
    
    final isToday = selected.isAtSameMomentAs(today);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.textSecondary.withValues(alpha: 0.2))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left, color: colors.textPrimary),
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
              if (!isToday)
                GestureDetector(
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
                ),
            ],
          ),
          IconButton(
            icon: Icon(Icons.chevron_right, color: colors.textPrimary),
            onPressed: () => provider.setSelectedDate(selected.add(const Duration(days: 1))),
          ),
        ],
      ),
    );
  }
}
