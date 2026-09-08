import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/state/timer_provider.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/colors.dart';
import '../../models/task.dart';

class TimerScreen extends StatefulWidget {
  final Task? initialTask;
  const TimerScreen({super.key, this.initialTask});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  Task? _selectedTask;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedTask = widget.initialTask;
    // Fetch active session on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final timer = context.read<TimerProvider>();
      // If there's already an active session with a task, use that task
      if (timer.activeSession?.taskId != null) {
        final tasks = context.read<ScheduleProvider>().activeTasks;
        final t = tasks.cast<Task?>().firstWhere(
          (t) => t?.id == timer.activeSession!.taskId,
          orElse: () => null,
        );
        if (t != null && mounted) setState(() => _selectedTask = t);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Force a rebuild when returning to foreground so display time is fresh
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
    }
  }

  Future<void> _startTimer() async {
    await context.read<TimerProvider>().startSession(taskId: _selectedTask?.id);
  }

  Future<void> _pauseTimer() async {
    await context.read<TimerProvider>().pauseSession();
  }

  Future<void> _resumeTimer() async {
    await context.read<TimerProvider>().resumeSession();
  }

  Future<void> _completeTimer() async {
    final timer = context.read<TimerProvider>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Complete session?'),
        content: Text('This will record ${timer.displayTime} of focus time${_selectedTask != null ? ' for "${_selectedTask!.title}"' : ''}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Complete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final completed = await timer.completeSession();
    if (completed != null && mounted) {
      // Refresh dashboard/tasks
      context.read<ScheduleProvider>().fetchDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Session complete — ${timer.displayTime} recorded!'),
          backgroundColor: context.eqColors.success,
        ),
      );
    }
  }

  Future<void> _discardTimer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard session?'),
        content: const Text('This session will not be recorded. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep going')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.eqColors.danger),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<TimerProvider>().discardSession();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final textTheme = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: const Text('Focus Timer'),
        centerTitle: false,
        backgroundColor: colors.background,
        elevation: 0,
      ),
      body: Consumer<TimerProvider>(
        builder: (context, timer, _) {
          final isIdle = timer.timerState == TimerState.idle;
          final isRunning = timer.timerState == TimerState.running;
          final isPaused = timer.timerState == TimerState.paused;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(EqTokens.space24),
            child: Column(
              children: [
                const SizedBox(height: EqTokens.space32),

                // --- Task Selector (only when idle) ---
                if (isIdle) ...[
                  _buildTaskSelector(colors, textTheme),
                  const SizedBox(height: EqTokens.space48),
                ],

                // --- Active task display ---
                if (!isIdle && timer.activeSession?.taskId != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space8),
                    decoration: BoxDecoration(
                      color: colors.surfaceElevated,
                      borderRadius: EqTokens.border24,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(CupertinoIcons.book, size: 14, color: colors.primary),
                        const SizedBox(width: EqTokens.space8),
                        Flexible(
                          child: Text(
                            _selectedTask?.title ?? timer.activeSession!.taskTitle ?? 'Focus Session',
                            style: textTheme.labelMedium?.copyWith(color: colors.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: EqTokens.space32),
                ],

                // --- Timer Display ---
                Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colors.surface,
                    border: Border.all(
                      color: isRunning ? colors.primary : isPaused ? colors.warning : colors.surfaceElevated,
                      width: isRunning ? 3 : 2,
                    ),
                    boxShadow: isRunning ? [
                      BoxShadow(color: colors.primary.withValues(alpha: 0.15), blurRadius: 30, spreadRadius: 5)
                    ] : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isRunning)
                        Text('FOCUSING', style: textTheme.labelSmall?.copyWith(
                          color: colors.primary, letterSpacing: 1.5))
                      else if (isPaused)
                        Text('PAUSED', style: textTheme.labelSmall?.copyWith(
                          color: colors.warning, letterSpacing: 1.5))
                      else
                        Text('READY', style: textTheme.labelSmall?.copyWith(
                          color: colors.textSecondary, letterSpacing: 1.5)),
                      const SizedBox(height: 8),
                      Text(
                        timer.displayTime,
                        style: textTheme.displayLarge?.copyWith(
                          color: colors.textPrimary.withValues(alpha: isRunning ? 1.0 : 0.6),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ).animate(
                  target: isRunning ? 1 : 0,
                  onPlay: (c) => c.repeat()
                ).shimmer(
                  delay: Duration.zero,
                  duration: const Duration(seconds: 2),
                  color: colors.primary.withValues(alpha: 0.1),
                ),

                const SizedBox(height: EqTokens.space48),

                // --- Control Buttons ---
                if (timer.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: EqTokens.space16),
                    child: Text(timer.errorMessage!, style: textTheme.bodySmall?.copyWith(color: colors.danger)),
                  ),

                if (isIdle) ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: timer.isLoading ? null : _startTimer,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start Session'),
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(EqTokens.space16),
                        shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                      ),
                    ),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: timer.isLoading ? null : _discardTimer,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Discard'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: colors.danger,
                            side: BorderSide(color: colors.danger.withValues(alpha: 0.5)),
                            padding: const EdgeInsets.all(EqTokens.space16),
                            shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                          ),
                        ),
                      ),
                      const SizedBox(width: EqTokens.space12),
                      if (isRunning)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: timer.isLoading ? null : _pauseTimer,
                            icon: const Icon(Icons.pause_rounded),
                            label: const Text('Pause'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.all(EqTokens.space16),
                              shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: timer.isLoading ? null : _resumeTimer,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Resume'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: colors.primary,
                              padding: const EdgeInsets.all(EqTokens.space16),
                              shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                            ),
                          ),
                        ),
                      const SizedBox(width: EqTokens.space12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: timer.isLoading ? null : _completeTimer,
                          icon: const Icon(Icons.check_rounded),
                          label: const Text('Done'),
                          style: FilledButton.styleFrom(
                            backgroundColor: colors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.all(EqTokens.space16),
                            shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                // --- Session History ---
                if (isIdle) ...[
                  const SizedBox(height: EqTokens.space48),
                  _buildHistory(timer, colors, textTheme),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskSelector(EqColors colors, TextTheme textTheme) {
    final tasks = context.read<ScheduleProvider>().activeTasks;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('SELECT TASK (OPTIONAL)', style: textTheme.labelSmall?.copyWith(
          color: colors.textSecondary, letterSpacing: 1.2)),
        const SizedBox(height: EqTokens.space12),
        GestureDetector(
          onTap: () async {
            final selected = await showModalBottomSheet<Task>(
              context: context,
              backgroundColor: colors.surface,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
              builder: (ctx) => _TaskPickerSheet(tasks: tasks),
            );
            if (mounted) setState(() => _selectedTask = selected ?? _selectedTask);
          },
          child: Container(
            padding: const EdgeInsets.all(EqTokens.space16),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: EqTokens.border12,
              border: Border.all(color: colors.surfaceElevated),
            ),
            child: Row(
              children: [
                Icon(CupertinoIcons.book, color: colors.primary, size: 20),
                const SizedBox(width: EqTokens.space12),
                Expanded(
                  child: Text(
                    _selectedTask?.title ?? 'Free focus session',
                    style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
                  ),
                ),
                Icon(Icons.chevron_right, color: colors.textSecondary),
              ],
            ),
          ),
        ),
        if (_selectedTask != null) ...[
          const SizedBox(height: EqTokens.space8),
          TextButton(
            onPressed: () => setState(() => _selectedTask = null),
            child: Text('Clear task', style: TextStyle(color: colors.textSecondary)),
          ),
        ],
      ],
    );
  }

  Widget _buildHistory(TimerProvider timer, EqColors colors, TextTheme textTheme) {
    if (timer.history.isEmpty) {
      return Column(
        children: [
          Icon(Icons.close, color: colors.textSecondary.withValues(alpha: 0.8)),
          const SizedBox(height: EqTokens.space8),
          Text('No sessions yet', style: textTheme.bodyMedium?.copyWith(color: colors.textSecondary)),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('RECENT SESSIONS', style: textTheme.labelSmall?.copyWith(
          color: colors.textSecondary, letterSpacing: 1.2)),
        const SizedBox(height: EqTokens.space12),
        ...timer.history.take(10).map((s) => Container(
          margin: const EdgeInsets.only(bottom: EqTokens.space8),
          padding: const EdgeInsets.all(EqTokens.space16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: EqTokens.border12,
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: colors.success, size: 18),
              const SizedBox(width: EqTokens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.taskTitle ?? 'Free session',
                      style: textTheme.bodySmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    Text(_formatDate(s.startedAt),
                      style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ),
              Text('${(s.elapsedSeconds ~/ 60)}m',
                style: textTheme.bodySmall?.copyWith(color: colors.primary, fontWeight: FontWeight.w600)),
            ],
          ),
        )),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _TaskPickerSheet extends StatelessWidget {
  final List<Task> tasks;
  const _TaskPickerSheet({required this.tasks});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final textTheme = context.eqText;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Text('Pick a task to focus on',
              style: textTheme.titleMedium?.copyWith(color: colors.textPrimary)),
          ),
          const Divider(),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: tasks.length,
              itemBuilder: (ctx, i) {
                final t = tasks[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  leading: Icon(Icons.radio_button_unchecked, color: colors.primary),
                  title: Text(t.title, style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary)),
                  subtitle: Text('${t.estimateMinutes}m • ${t.cognitiveLoad}',
                    style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                  onTap: () => Navigator.pop(ctx, t),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
