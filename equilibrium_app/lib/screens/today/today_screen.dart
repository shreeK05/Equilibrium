import 'package:flutter/cupertino.dart';
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
import '../../widgets/forms/create_task_sheet.dart';
import '../../widgets/dialogs/task_progress_dialog.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/state/profile_provider.dart';
import '../../core/utils/workload_calculator.dart';
import '../../models/task.dart';
import '../../models/schedule.dart';
import '../../models/decision_log.dart';
import 'package:intl/intl.dart';
import '../timer/timer_screen.dart';

class _TodayTaskEntry {
  final Task task;
  final int scheduledMinutesToday;
  final DateTime earliestStartTime;
  final bool isCompleted;

  const _TodayTaskEntry({
    required this.task,
    required this.scheduledMinutesToday,
    required this.earliestStartTime,
    required this.isCompleted,
  });
}

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

  Future<void> _handleTaskDone(Task task, [int? scheduledBlockMinutes]) async {
    final result = await TaskProgressDialog.show(
      context,
      task: task,
      scheduledBlockMinutes: scheduledBlockMinutes,
    );

    if (!mounted || result == null) return;

    if (result.replanSummary != null) {
      _showReplanSnackbar(result.replanSummary!);
    } else if (result.action == TaskProgressAction.finished) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Completed "${task.title}"! 🎉'),
          backgroundColor: context.eqColors.success,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Undo',
            textColor: Colors.white,
            onPressed: () async {
              await context.read<ScheduleProvider>().reopenTask(task.id);
            },
          ),
        ),
      );
    } else if (result.action == TaskProgressAction.madeProgress) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recorded progress for "${task.title}".'),
          backgroundColor: context.eqColors.primary,
        ),
      );
    }
  }

  void _showReplanSnackbar(ReplanSummary summary) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(summary.userMessage),
        backgroundColor: summary.hasDeferred ? context.eqColors.warning : context.eqColors.success,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Dismiss',
          textColor: Colors.black,
          onPressed: () {},
        ),
      ),
    );
  }

  void _openCreateTask(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateTaskSheet(),
    );
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
            final allTasks = provider.activeTasks;
            final now = DateTime.now();
            final dayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);
            final dayEnd = DateTime(now.year, now.month, now.day + 1, 0, 0, 0);

            bool overlapsToday(DateTime start, DateTime end) =>
                start.isBefore(dayEnd) && end.isAfter(dayStart);

            final allBlocks = schedule?.blocks ?? <ScheduleBlock>[];

            // 1. Filter to active TASK blocks overlapping today
            final todayTaskBlocks = allBlocks
                .where((b) => b.type == 'TASK' && b.taskId != null && overlapsToday(b.startTime, b.endTime))
                .toList();

            // 2. Group blocks by taskId to deduplicate and compute scheduled minutes today
            final Map<String, List<ScheduleBlock>> taskBlocksById = {};
            for (final b in todayTaskBlocks) {
              taskBlocksById.putIfAbsent(b.taskId!, () => []).add(b);
            }

            final List<_TodayTaskEntry> todayTasks = [];
            for (final entry in taskBlocksById.entries) {
              final taskId = entry.key;
              final blocks = entry.value;
              final task = allTasks.cast<Task?>().firstWhere((t) => t?.id == taskId, orElse: () => null);
              if (task == null) continue;

              int scheduledMinutesToday = 0;
              for (final b in blocks) {
                final s = b.startTime.isBefore(dayStart) ? dayStart : b.startTime;
                final e = b.endTime.isAfter(dayEnd) ? dayEnd : b.endTime;
                if (s.isBefore(e)) {
                  scheduledMinutesToday += e.difference(s).inMinutes;
                }
              }

              blocks.sort((a, b) => a.startTime.compareTo(b.startTime));
              todayTasks.add(_TodayTaskEntry(
                task: task,
                scheduledMinutesToday: scheduledMinutesToday,
                earliestStartTime: blocks.first.startTime,
                isCompleted: task.isCompleted || blocks.every((b) => b.isCompleted),
              ));
            }
            // Sort chronologically by earliest block today
            todayTasks.sort((a, b) => a.earliestStartTime.compareTo(b.earliestStartTime));

            // 3. Needs Attention tasks: active, non-completed tasks NOT scheduled today that are overdue or due today
            final todayScheduledTaskIds = taskBlocksById.keys.toSet();
            final needsAttentionTasks = allTasks.where((t) {
              if (t.status == TaskStatus.completed) return false;
              if (todayScheduledTaskIds.contains(t.id)) return false;
              return t.isOverdue || t.isDueToday || t.deadline.isBefore(dayEnd);
            }).toList();

            final hasTodayCommitments = provider.commitments.any(
              (c) => c.isActive && overlapsToday(c.startTime, c.endTime),
            );

            // Empty state condition: nothing today and no urgent tasks needing attention
            if (todayTasks.isEmpty && !hasTodayCommitments && needsAttentionTasks.isEmpty) {
              return EmptyStateWidget(
                title: allTasks.isEmpty ? 'Your workload is clear.' : 'Your workload is ready.',
                message: allTasks.isEmpty
                    ? 'Add your first responsibility to begin balancing your days.'
                    : "Generate your adaptive study plan for today.",
                icon: allTasks.isEmpty ? CupertinoIcons.square_list : CupertinoIcons.sparkles,
                actionLabel: allTasks.isEmpty ? 'Add First Task' : 'Generate Schedule',
                onAction: allTasks.isEmpty
                    ? () => _openCreateTask(context)
                    : provider.generateSchedule,
              ).animate().fade().scale(begin: const Offset(0.95, 0.95));
            }

            // 4. Calculate real mathematical capacity from intervals and constraints
            final sleepStart = provider.constraints?['sleepStart'] as String? ?? '23:00';
            final sleepEnd = provider.constraints?['sleepEnd'] as String? ?? '07:00';
            final bufferMinutes = provider.constraints?['bufferMinutes'] as int? ?? 15;

            final workload = WorkloadCalculator.calculateCapacity(
              date: now,
              sleepStart: sleepStart,
              sleepEnd: sleepEnd,
              commitments: provider.commitments,
              bufferMinutes: bufferMinutes,
              blocks: allBlocks,
            );

            final plannedMinutes = workload.plannedMinutes;
            final availableMinutes = workload.availableCapacityMinutes;

            final sleepHours = WorkloadCalculator.calculateSleepDurationHours(sleepStart, sleepEnd);
            final int sleepH = sleepHours.floor();
            final int sleepM = ((sleepHours - sleepH) * 60).round();
            final sleepDuration = sleepM > 0
                ? '${sleepH}h ${sleepM.toString().padLeft(2, '0')}m'
                : '${sleepH}h 00m';

            final profile = context.watch<ProfileProvider>().profile;
            final studentName = profile?.name ?? 'Student';
            final dateStr = DateFormat('EEEE, MMMM d').format(now);

            final hour = now.hour;
            String greeting = 'GOOD EVENING';
            if (hour < 12) {
              greeting = 'GOOD MORNING';
            } else if (hour < 17) {
              greeting = 'GOOD AFTERNOON';
            }

            // Identify Up Next task block (first non-completed task block finishing after now, or first non-completed today)
            final nonCompletedBlocks = todayTaskBlocks.where((b) {
              if (b.isCompleted) return false;
              final task = allTasks.cast<Task?>().firstWhere((t) => t?.id == b.taskId, orElse: () => null);
              return task != null && !task.isCompleted;
            }).toList();

            final nextTaskBlock = nonCompletedBlocks.cast<ScheduleBlock?>().firstWhere(
              (b) => b != null && b.endTime.isAfter(now) && !b.isLocked,
              orElse: () => nonCompletedBlocks.isNotEmpty ? nonCompletedBlocks.first : null,
            );

            Task? upNextTask;
            if (nextTaskBlock != null && nextTaskBlock.taskId != null) {
              upNextTask = allTasks.cast<Task?>().firstWhere(
                (t) => t != null && t.id == nextTaskBlock.taskId && !t.isCompleted,
                orElse: () => null,
              );
            }

            return RefreshIndicator(
              onRefresh: provider.fetchDashboardData,
              color: colors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: EqTokens.space24, vertical: EqTokens.space20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Greeting & Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                greeting,
                                style: text.labelSmall?.copyWith(
                                  color: colors.textSecondary,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ).animate().fade().slideY(begin: -0.2),
                              const SizedBox(height: EqTokens.space4),
                              Text(
                                studentName,
                                style: text.headlineLarge?.copyWith(
                                  color: colors.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.5,
                                ),
                              ).animate().fade(delay: 80.ms).slideY(begin: -0.2),
                              const SizedBox(height: EqTokens.space4),
                              Text(
                                dateStr,
                                style: text.bodyMedium?.copyWith(
                                  color: colors.textSecondary,
                                ),
                              ).animate().fade(delay: 120.ms),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: EqTokens.space24),

                    // 1. "Up Next" Hero Task Section (Immediate next action)
                    if (upNextTask != null && nextTaskBlock != null) ...[
                      _buildSectionTitle(context, 'Up Next').animate().fade(delay: 140.ms),
                      const SizedBox(height: EqTokens.space12),
                      _buildUpNextHeroCard(
                        context,
                        task: upNextTask,
                        block: nextTaskBlock,
                        onComplete: () => _handleTaskDone(upNextTask!, nextTaskBlock.durationMinutes),
                        onStartTimer: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => TimerScreen(initialTask: upNextTask),
                          ));
                        },
                      ).animate().fade(delay: 180.ms).slideY(begin: 0.1),
                      const SizedBox(height: EqTokens.space28),
                    ],

                    // 2. Daily Planned-vs-Capacity Summary
                    _buildSectionTitle(context, 'Daily Workload & Capacity').animate().fade(delay: 200.ms),
                    const SizedBox(height: EqTokens.space12),
                    Container(
                      padding: const EdgeInsets.all(EqTokens.space16),
                      decoration: BoxDecoration(
                        color: colors.surface,
                        borderRadius: EqTokens.border16,
                        border: Border.all(color: colors.cardBorder),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          WorkloadMeter(
                            plannedMinutes: plannedMinutes,
                            availableMinutes: availableMinutes,
                          ),
                          const SizedBox(height: EqTokens.space12),
                          _buildCapacityStatusText(context, plannedMinutes, availableMinutes),
                          if (provider.currentSchedule != null) ...[
                            const SizedBox(height: EqTokens.space12),
                            Divider(color: colors.cardBorder),
                            const SizedBox(height: EqTokens.space8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: provider.isLoading
                                    ? null
                                    : () async {
                                        final summary = await provider.reschedule();
                                        if (mounted && summary != null) {
                                          _showReplanSnackbar(summary);
                                        }
                                      },
                                icon: const Icon(CupertinoIcons.arrow_2_circlepath, size: 16),
                                label: const Text('Re-plan remaining day'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ).animate().fade(delay: 240.ms).scale(begin: const Offset(0.98, 0.98)),
                    const SizedBox(height: EqTokens.space28),

                    // 3. Sleep Shield Protection
                    _buildSectionTitle(context, 'Protected Rest').animate().fade(delay: 260.ms),
                    const SizedBox(height: EqTokens.space12),
                    SleepShield(
                      startTime: sleepStart,
                      endTime: sleepEnd,
                      durationStr: sleepDuration,
                    ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
                    const SizedBox(height: EqTokens.space28),

                    // 4. Needs Attention Section (for urgent unscheduled or overdue work)
                    if (needsAttentionTasks.isNotEmpty) ...[
                      _buildSectionTitle(context, 'Needs Attention', isUrgent: true).animate().fade(delay: 320.ms),
                      const SizedBox(height: EqTokens.space8),
                      Text(
                        'Unscheduled work due today or overdue',
                        style: text.bodySmall?.copyWith(color: colors.warning),
                      ).animate().fade(delay: 330.ms),
                      const SizedBox(height: EqTokens.space12),
                      ...needsAttentionTasks.map((task) {
                        final decisionLog = provider.currentSchedule?.decisionLogs.cast<DecisionLog?>().firstWhere(
                          (d) => d?.taskId == task.id && d?.decisionType == DecisionType.deferred,
                          orElse: () => null,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(bottom: EqTokens.space12),
                          child: GestureDetector(
                            onTap: () {
                              showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (context) => TaskDetailSheet(task: task),
                              );
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                TaskCard(
                                  title: task.title,
                                  category: task.category,
                                  durationStr: '${task.remainingMinutes}m',
                                  deadlineStr: task.isOverdue ? 'Overdue' : 'Due today',
                                  isFlexible: task.deadlineType == DeadlineType.flexible,
                                  status: EqStatus.deferred,
                                  isCompleted: false,
                                  onComplete: () => _handleTaskDone(task),
                                  onStartTimer: () {
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (_) => TimerScreen(initialTask: task),
                                    ));
                                  },
                                ),
                                if (decisionLog != null) ...[
                                  const SizedBox(height: EqTokens.space6),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(horizontal: EqTokens.space12, vertical: EqTokens.space8),
                                    decoration: BoxDecoration(
                                      color: colors.warning.withValues(alpha: 0.1),
                                      borderRadius: EqTokens.border8,
                                      border: Border.all(color: colors.warning.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 14, color: colors.warning),
                                        const SizedBox(width: EqTokens.space8),
                                        Expanded(
                                          child: Text(
                                            decisionLog.humanReadable,
                                            style: text.bodySmall?.copyWith(color: colors.textPrimary),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ).animate().fade(delay: 350.ms).slideX(begin: 0.1);
                      }),
                      const SizedBox(height: EqTokens.space24),
                    ],

                    // 5. Today's Scheduled Tasks
                    _buildSectionTitle(context, "Today's Tasks").animate().fade(delay: 360.ms),
                    const SizedBox(height: EqTokens.space12),
                    if (todayTasks.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(EqTokens.space20),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: EqTokens.border16,
                          border: Border.all(color: colors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Icon(CupertinoIcons.checkmark_seal, size: 36, color: colors.success),
                            const SizedBox(height: EqTokens.space8),
                            Text(
                              'No remaining tasks scheduled for today',
                              style: text.titleSmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: EqTokens.space4),
                            Text(
                              'Enjoy your downtime or get ahead on upcoming assignments.',
                              style: text.bodySmall?.copyWith(color: colors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ...todayTasks.map((entry) {
                        final task = entry.task;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: EqTokens.space12),
                          child: GestureDetector(
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
                              category: task.category,
                              durationStr: '${entry.scheduledMinutesToday}m',
                              deadlineStr: task.isDueToday
                                  ? 'Due today'
                                  : task.isOverdue
                                      ? 'Overdue'
                                      : 'Due in ${task.deadline.difference(now).inDays} days',
                              isFlexible: task.deadlineType == DeadlineType.flexible,
                              status: _mapStatus(task.status),
                              isCompleted: entry.isCompleted,
                              onComplete: () => _handleTaskDone(task, entry.scheduledMinutesToday),
                              onStartTimer: () {
                                Navigator.of(context).push(MaterialPageRoute(
                                  builder: (_) => TimerScreen(initialTask: task),
                                ));
                              },
                            ),
                          ),
                        ).animate().fade(delay: 400.ms).slideX(begin: 0.1);
                      }),
                    const SizedBox(height: EqTokens.space48),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, {bool isUrgent = false}) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Row(
      children: [
        if (isUrgent) ...[
          Icon(CupertinoIcons.exclamationmark_triangle_fill, size: 14, color: colors.warning),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            title.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(
              color: isUrgent ? colors.warning : colors.textSecondary,
              letterSpacing: 1.0,
              fontWeight: isUrgent ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCapacityStatusText(BuildContext context, int planned, int available) {
    final colors = context.eqColors;
    final text = context.eqText;

    if (available <= 0 && planned > 0) {
      return Text(
        'Zero open study capacity today without encroaching on sleep or fixed commitments.',
        style: text.bodySmall?.copyWith(color: colors.warning),
      );
    }
    if (planned > available) {
      final over = planned - available;
      return Text(
        'Workload exceeds available daily capacity (${over}m over). The scheduler has deferred low-priority tasks to protect your bedtime.',
        style: text.bodySmall?.copyWith(color: colors.warning),
      );
    }
    if (planned == 0) {
      return Text(
        'No study blocks currently scheduled for today.',
        style: text.bodySmall?.copyWith(color: colors.textSecondary),
      );
    }
    return Text(
      'Balanced workload: $planned minutes scheduled cleanly within $available minutes of daily study capacity.',
      style: text.bodySmall?.copyWith(color: colors.success),
    );
  }

  Widget _buildUpNextHeroCard(
    BuildContext context, {
    required Task task,
    required ScheduleBlock block,
    required VoidCallback onComplete,
    required VoidCallback onStartTimer,
  }) {
    final colors = context.eqColors;
    final text = context.eqText;

    final startStr = DateFormat('h:mm a').format(block.startTime);
    final endStr = DateFormat('h:mm a').format(block.endTime);

    return Material(
      color: colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: EqTokens.border16,
        side: BorderSide(color: colors.primary.withValues(alpha: 0.3), width: 1.5),
      ),
      child: InkWell(
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => TaskDetailSheet(task: task),
          );
        },
        borderRadius: EqTokens.border16,
        child: Padding(
          padding: const EdgeInsets.all(EqTokens.space16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: EqTokens.space8,
                runSpacing: EqTokens.space6,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: EqTokens.border8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            '$startStr – $endStr',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: colors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (task.category != null)
                    Text(
                      task.category!.toUpperCase(),
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: EqTokens.space12),
              Text(
                task.title,
                style: text.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: EqTokens.space6),
              Text(
                '${block.durationMinutes}m focus chunk • ${task.remainingMinutes}m remaining',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: EqTokens.space16),
              Wrap(
                spacing: EqTokens.space12,
                runSpacing: EqTokens.space8,
                children: [
                  ElevatedButton.icon(
                    onPressed: onStartTimer,
                    icon: const Icon(CupertinoIcons.play_fill, size: 16),
                    label: const Text('Start Focus'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: onComplete,
                    icon: const Icon(CupertinoIcons.checkmark_alt, size: 16),
                    label: const Text('Progress'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  EqStatus _mapStatus(TaskStatus status) {
    switch (status) {
      case TaskStatus.inProgress:
        return EqStatus.partiallyScheduled;
      case TaskStatus.partiallyCompleted:
        return EqStatus.partiallyScheduled;
      case TaskStatus.completed:
        return EqStatus.completed;
      default:
        return EqStatus.deferred;
    }
  }
}
