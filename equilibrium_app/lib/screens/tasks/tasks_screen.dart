import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../widgets/cards/task_card.dart';
import '../../widgets/forms/task_detail_sheet.dart';
import '../../widgets/status/empty_state.dart';
import '../../widgets/status/status_badge.dart';
import '../../models/task.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(EqTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'YOUR WORKLOAD',
                  style: text.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ).animate().fade().slideY(begin: -0.2),
                const SizedBox(height: EqTokens.space8),
                Text(
                  'Master Task List',
                  style: text.headlineLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ).animate().fade(delay: 100.ms).slideY(begin: -0.2),
              ],
            ),
          ),
          
          TabBar(
            controller: _tabController,
            indicatorColor: colors.primary,
            labelColor: colors.primary,
            unselectedLabelColor: colors.textSecondary,
            dividerColor: colors.surfaceElevated,
            tabs: const [
              Tab(text: 'Pending'),
              Tab(text: 'Scheduled'),
              Tab(text: 'Completed'),
            ],
          ).animate().fade(delay: 200.ms),
          
          Expanded(
            child: Consumer<ScheduleProvider>(
              builder: (context, provider, child) {
                final tasks = provider.activeTasks;

                final scheduledIds = provider.currentSchedule?.blocks
                    .where((block) => block.type == 'TASK' && block.taskId != null)
                    .map((block) => block.taskId!)
                    .toSet() ?? <String>{};
                final pending = tasks.where((t) {
                  if (t.status == TaskStatus.completed || t.status == TaskStatus.archived) return false;
                  return !scheduledIds.contains(t.id);
                }).toList();
                final scheduled = tasks.where((t) =>
                    t.status != TaskStatus.completed &&
                    t.status != TaskStatus.archived &&
                    scheduledIds.contains(t.id)).toList();
                final completed = tasks.where((t) => t.status == TaskStatus.completed).toList();

                return TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(pending, 'No pending tasks', 'New tasks you create will appear here.'),
                    _buildTaskList(scheduled, 'No scheduled tasks', 'Tap Generate Schedule on the Schedule screen.'),
                    _buildTaskList(completed, 'No completed tasks', 'Completed work will appear here.'),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskList(List tasks, String emptyTitle, String emptyMessage) {
    if (tasks.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          title: emptyTitle,
          message: emptyMessage,
          icon: Icons.check_circle_outline,
        ),
      ).animate().fade();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(EqTokens.space24),
      itemCount: tasks.length,
      separatorBuilder: (context, index) => const SizedBox(height: EqTokens.space16),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Dismissible(
          key: Key(task.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 24),
            decoration: BoxDecoration(
              color: context.eqColors.danger,
              borderRadius: EqTokens.border16,
            ),
            child: Icon(Icons.delete_outline, color: context.eqColors.surface),
          ),
          onDismissed: (direction) {
            context.read<ScheduleProvider>().deleteTask(task.id);
          },
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
              subject: task.subjectName,
              category: task.category,
              durationStr: '${task.estimateMinutes}m',
              deadlineStr: 'Due in ${task.deadline.difference(DateTime.now()).inDays} days',
              isFlexible: task.deadlineType == DeadlineType.flexible,
              status: _mapStatus(task.status),
            ),
          ),
        ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1);
      },
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
