import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/timeline/timeline.dart';
import '../../widgets/timeline/timeline_block.dart';
import '../../widgets/status/loading_skeleton.dart';
import '../../widgets/status/empty_state.dart';
import '../../widgets/status/error_state.dart';
import '../../core/state/schedule_provider.dart';
import '../../widgets/status/workload_meter.dart' as equilibrium_app_workload;
import '../../widgets/status/change_summary.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Signature Schedule'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<ScheduleProvider>().fetchDashboardData();
            },
          )
        ],
      ),
      body: Consumer<ScheduleProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.currentSchedule == null) {
            return const EquilibriumLoadingState();
          }

          if (provider.errorMessage != null && provider.currentSchedule == null) {
            return ErrorStateWidget(
              title: 'Schedule unavailable',
              message: provider.errorMessage!,
              onRetry: provider.fetchDashboardData,
            );
          }

          final schedule = provider.currentSchedule;
          
          if (provider.activeTasks.isEmpty && (schedule == null || schedule.blocks.isEmpty)) {
            return const EmptyStateWidget(
              title: 'Nothing needs scheduling yet.',
              message: 'Add tasks and let Equilibrium balance your workload.',
              icon: Icons.auto_awesome,
            );
          }

          if (schedule == null || schedule.blocks.isEmpty) {
            return const EmptyStateWidget(
              title: 'Your workload is ready to be balanced.',
              message: 'Generate a schedule to let Equilibrium optimize your day.',
              icon: Icons.calendar_today_outlined,
            );
          }

          int plannedMinutes = 0;
          for (var t in provider.activeTasks) {
            plannedMinutes += t.remainingMinutes;
          }

          int availableMinutes = 0;
          if (schedule != null) {
            for (var b in schedule.blocks) {
              if (b.type == 'FREE' || b.type == 'TASK') {
                availableMinutes += b.durationMinutes;
              }
            }
          }

          return Column(
            children: [
              if (provider.previousSchedule != null)
                ChangeSummaryBanner(
                  currentSchedule: schedule,
                  previousSchedule: provider.previousSchedule,
                  onDismiss: provider.clearChangeSummary,
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
                child: equilibrium_app_workload.WorkloadMeter(
                  plannedMinutes: plannedMinutes,
                  availableMinutes: availableMinutes > 0 ? availableMinutes : plannedMinutes, // Fallback if no schedule
                ),
              ),
              Expanded(
                child: ScheduleTimeline(
                  schedule: schedule,
                  tasks: provider.activeTasks,
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<ScheduleProvider>(
        builder: (context, provider, child) {
          if (provider.currentSchedule == null || provider.isLoading) {
            return const SizedBox.shrink();
          }
          return FloatingActionButton.extended(
            onPressed: () => provider.reschedule(),
            icon: const Icon(Icons.auto_fix_high),
            label: const Text('Reschedule'),
            backgroundColor: colors.primary,
            foregroundColor: colors.surface,
          );
        },
      ),
    );
  }
}
