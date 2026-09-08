import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
import '../../models/task.dart';
import '../../models/schedule.dart';

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
              ).animate().fade().scale(begin: const Offset(0.95, 0.95));
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
              ).animate().fade().scale(begin: const Offset(0.95, 0.95));
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

            final sleepStart = provider.constraints?['sleepStart'] as String? ?? '23:00';
            final sleepEnd = provider.constraints?['sleepEnd'] as String? ?? '06:00';
            final minHours = provider.constraints?['minSleepHours'] as int? ?? 7;
            final sleepDuration = '${minHours}h 00m';

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
                    ).animate().fade().slideY(begin: -0.2),
                    const SizedBox(height: EqTokens.space8),
                    Text(
                      provider.errorMessage != null ? 'Running offline.' : 'Your workload is balanced.',
                      style: text.headlineLarge?.copyWith(
                        color: colors.textPrimary,
                      ),
                    ).animate().fade(delay: 100.ms).slideY(begin: -0.2),
                    const SizedBox(height: EqTokens.space32),
                    
                    _buildSectionTitle(context, 'Today').animate().fade(delay: 150.ms),
                    const SizedBox(height: EqTokens.space16),
                    WorkloadMeter(
                      plannedMinutes: plannedMinutes,
                      availableMinutes: availableMinutes,
                    ).animate().fade(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
                    
                    const SizedBox(height: EqTokens.space32),
                    
                    Builder(builder: (context) {
                      final now = DateTime.now();
                      final nextTaskBlock = schedule.blocks.cast<ScheduleBlock?>().firstWhere(
                        (b) => b != null && b.type == 'TASK' && b.endTime.isAfter(now),
                        orElse: () => null,
                      );
                      
                      if (nextTaskBlock != null && nextTaskBlock.taskId != null) {
                        final task = tasks.cast<Task?>().firstWhere(
                          (t) => t != null && t.id == nextTaskBlock.taskId,
                          orElse: () => null,
                        );
                        
                        if (task != null) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSectionTitle(context, 'Up Next').animate().fade(delay: 250.ms),
                              const SizedBox(height: EqTokens.space16),
                              GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (context) => TaskDetailSheet(task: task),
                                  );
                                },
                                child: TaskCard(
                                  title: task.title,
                                  subject: task.subjectName,
                                  category: task.category,
                                  durationStr: '${nextTaskBlock.durationMinutes}m',
                                  deadlineStr: 'Due in ${task.deadline.difference(DateTime.now()).inDays} days',
                                  isFlexible: task.deadlineType.name.toUpperCase() == 'FLEXIBLE',
                                  status: _mapStatus(task.status),
                                ),
                              ).animate().fade(delay: 300.ms).slideX(begin: 0.1),
                              const SizedBox(height: EqTokens.space32),
                            ],
                          );
                        }
                      }
                      return const SizedBox.shrink();
                    }),
                    
                    _buildSectionTitle(context, 'Sleep Shield').animate().fade(delay: 350.ms),
                    const SizedBox(height: EqTokens.space16),
                    
                    SleepShield(
                      startTime: sleepStart,
                      endTime: sleepEnd,
                      durationStr: sleepDuration,
                    ).animate().fade(delay: 400.ms).slideY(begin: 0.1),
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

  EqStatus _mapStatus(dynamic taskStatus) {
    switch (taskStatus.name) {
      case 'scheduled': return EqStatus.scheduled;
      case 'partiallyCompleted': return EqStatus.partiallyScheduled;
      case 'inProgress': return EqStatus.partiallyScheduled;
      case 'completed': return EqStatus.completed;
      default: return EqStatus.deferred;
    }
  }
}
