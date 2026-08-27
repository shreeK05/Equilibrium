import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/timeline/sleep_shield.dart';
import '../../widgets/status/status_badge.dart';
import '../../widgets/status/workload_meter.dart';
import '../../widgets/status/loading_skeleton.dart';
import '../../widgets/status/error_state.dart';
import '../../widgets/status/empty_state.dart';
import '../../widgets/forms/task_detail_sheet.dart';
import '../../core/state/schedule_provider.dart';

class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});

  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ScheduleProvider>().fetchDashboardData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Consumer<ScheduleProvider>(
          builder: (context, provider, child) {
            if (provider.isLoading && provider.currentSchedule == null) {
              return const EquilibriumLoadingState();
            }

            if (provider.errorMessage != null && provider.currentSchedule == null) {
              return ErrorStateWidget(
                title: 'Could not load today',
                message: provider.errorMessage!,
                onRetry: provider.fetchDashboardData,
              );
            }

            final schedule = provider.currentSchedule;
            final tasks = provider.activeTasks;

            if (schedule == null || schedule.blocks.isEmpty) {
              return EmptyStateWidget(
                title: tasks.isEmpty ? 'Your workload is clear.' : 'Your workload is ready.',
                message: tasks.isEmpty ? "Add your first assignment to begin." : "Let's balance your first day.",
                icon: Icons.done_all,
                actionLabel: tasks.isNotEmpty ? 'Generate Schedule' : null,
                onAction: tasks.isNotEmpty ? provider.generateSchedule : null,
              );
            }

            // Extract real metrics
            final int plannedMinutes = schedule.blocks
                .where((b) => b.type == 'TASK')
                .fold(0, (sum, b) => sum + b.durationMinutes);
            
            // Calculate total capacity natively based on blocks
            int availableMinutes = 0;
            for (var b in schedule.blocks) {
              if (b.type == 'FREE' || b.type == 'TASK') {
                availableMinutes += b.durationMinutes;
              }
            }
            if (availableMinutes == 0) availableMinutes = plannedMinutes; // fallback

            final sleepBlock = schedule.blocks.firstWhere(
              (b) => b.type == 'SLEEP',
              orElse: () => schedule.blocks.first,
            );
            final sleepStart = '${sleepBlock.startTime.hour.toString().padLeft(2, '0')}:${sleepBlock.startTime.minute.toString().padLeft(2, '0')}';
            final sleepEnd = '${sleepBlock.endTime.hour.toString().padLeft(2, '0')}:${sleepBlock.endTime.minute.toString().padLeft(2, '0')}';
            final sleepDuration = '${sleepBlock.durationMinutes ~/ 60}h ${sleepBlock.durationMinutes % 60}m';

            return RefreshIndicator(
              onRefresh: provider.fetchDashboardData,
              color: colors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(EqTokens.space24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GOOD MORNING',
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: EqTokens.space8),
                    Text(
                      provider.errorMessage != null ? 'Running offline.' : 'Your workload is balanced.',
                      style: text.headlineLarge?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: EqTokens.space32),
                    
                    _buildSectionTitle(context, 'Today'),
                    const SizedBox(height: EqTokens.space16),
                    WorkloadMeter(
                      plannedMinutes: plannedMinutes,
                      availableMinutes: availableMinutes,
                    ),
                    
                    const SizedBox(height: EqTokens.space32),
                    if (tasks.isNotEmpty) ...[
                      _buildSectionTitle(context, 'Next'),
                      const SizedBox(height: EqTokens.space16),
                      GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => TaskDetailSheet(task: tasks.first),
                          );
                        },
                        child: TaskCard(
                          title: tasks.first.title,
                          subject: 'ACADEMIC', // Fallback or extracted
                          durationStr: '${tasks.first.estimateMinutes}m',
                          deadlineStr: 'Deadline', // Formatting omitted for brevity
                          status: EqStatus.scheduled,
                        ),
                      ),
                      const SizedBox(height: EqTokens.space32),
                    ],

                    _buildSectionTitle(context, 'Sleep Shield'),
                    const SizedBox(height: EqTokens.space16),
                    
                    SleepShield(
                      startTime: sleepStart,
                      endTime: sleepEnd,
                      durationStr: sleepDuration,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title.toUpperCase(),
      style: context.eqText.labelSmall?.copyWith(
        color: context.eqColors.textSecondary,
        letterSpacing: 1.0,
      ),
    );
  }
}
