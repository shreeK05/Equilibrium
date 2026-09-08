import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/state/exam_provider.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/exam.dart';
import '../../widgets/status/empty_state.dart';
import '../../widgets/status/loading_skeleton.dart';

class ExamsScreen extends StatefulWidget {
  const ExamsScreen({super.key});

  @override
  State<ExamsScreen> createState() => _ExamsScreenState();
}

class _ExamsScreenState extends State<ExamsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ExamProvider>().fetchAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final textTheme = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: Consumer<ExamProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading && provider.exams.isEmpty) {
              return const EquilibriumLoadingState();
            }
            return RefreshIndicator(
              onRefresh: provider.fetchAll,
              color: colors.primary,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                    sliver: SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('EXAM PREPARATION', style: textTheme.labelSmall?.copyWith(
                            color: colors.textSecondary, letterSpacing: 1.2)),
                          const SizedBox(height: EqTokens.space8),
                          Row(
                            children: [
                              Expanded(
                                child: Text('Your Exams', style: textTheme.headlineLarge?.copyWith(
                                  color: colors.textPrimary)),
                              ),
                              FilledButton.icon(
                                onPressed: () => _showCreateExamDialog(context, provider),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Add Exam'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: colors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: EqTokens.space24),
                        ],
                      ),
                    ),
                  ),

                  if (provider.exams.isEmpty)
                    SliverFillRemaining(
                      child: EmptyStateWidget(
                        title: 'No exams yet',
                        message: 'Add an upcoming exam to start tracking your preparation.',
                        icon: CupertinoIcons.book_circle,
                        actionLabel: 'Add First Exam',
                        onAction: () => _showCreateExamDialog(context, provider),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final exam = provider.exams[i];
                            return _ExamCard(exam: exam, provider: provider)
                              .animate().fade(delay: (i * 60).ms).slideY(begin: 0.1);
                          },
                          childCount: provider.exams.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _showCreateExamDialog(BuildContext context, ExamProvider provider) async {
    final titleCtrl = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 14));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.eqColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Exam', style: ctx.eqText.titleLarge?.copyWith(color: ctx.eqColors.textPrimary)),
              const SizedBox(height: 20),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Exam Title (e.g. DBMS End Semester)',
                  border: OutlineInputBorder(borderRadius: EqTokens.border12),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(CupertinoIcons.calendar, color: ctx.eqColors.primary),
                title: Text('Exam Date', style: TextStyle(color: ctx.eqColors.textSecondary, fontSize: 13)),
                subtitle: Text(DateFormat('d MMM yyyy').format(selectedDate),
                  style: TextStyle(color: ctx.eqColors.textPrimary, fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setModalState(() => selectedDate = picked);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    final exam = await provider.createExam(
                      title: titleCtrl.text.trim(),
                      examDate: selectedDate,
                    );
                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      if (exam != null) {
                        _openExamDetail(context, exam, provider);
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ctx.eqColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                  ),
                  child: const Text('Create Exam'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleCtrl.dispose();
  }

  void _openExamDetail(BuildContext context, Exam exam, ExamProvider provider) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ExamDetailScreen(exam: exam),
    ));
  }
}

// ─── Exam Card ─────────────────────────────────────────────────────────────────

class _ExamCard extends StatelessWidget {
  final Exam exam;
  final ExamProvider provider;

  const _ExamCard({required this.exam, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final textTheme = context.eqText;
    final daysLeft = exam.daysUntilExam;
    final isUrgent = daysLeft <= 3 && daysLeft >= 0;
    final isPast = daysLeft < 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ExamDetailScreen(exam: exam),
        )).then((_) => provider.fetchAll());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: EqTokens.space16),
        padding: const EdgeInsets.all(EqTokens.space20),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: EqTokens.border16,
          border: isUrgent ? Border.all(color: colors.warning, width: 1.5) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(exam.title,
                    style: textTheme.titleMedium?.copyWith(color: colors.textPrimary),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPast ? colors.textSecondary.withValues(alpha: 0.15)
                        : isUrgent ? colors.warning.withValues(alpha: 0.15)
                        : colors.primary.withValues(alpha: 0.1),
                    borderRadius: EqTokens.border24,
                  ),
                  child: Text(
                    isPast ? 'Past'
                        : daysLeft == 0 ? 'TODAY'
                        : '$daysLeft days',
                    style: textTheme.labelSmall?.copyWith(
                      color: isPast ? colors.textSecondary
                          : isUrgent ? colors.warning
                          : colors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space8),
            Text(DateFormat('EEEE, d MMMM yyyy').format(exam.examDate),
              style: textTheme.bodySmall?.copyWith(color: colors.textSecondary)),

            if (exam.topics.isNotEmpty) ...[
              const SizedBox(height: EqTokens.space16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Coverage', style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                        const SizedBox(height: 4),
                        ClipRRect(
                          borderRadius: EqTokens.border8,
                          child: LinearProgressIndicator(
                            value: exam.coveragePercent / 100,
                            backgroundColor: colors.surfaceElevated,
                            color: colors.success,
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: EqTokens.space16),
                  Text('${exam.coveragePercent}%',
                    style: textTheme.titleMedium?.copyWith(color: colors.success, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: EqTokens.space8),
              Row(
                children: [
                  Icon(Icons.menu_book_outlined, size: 14, color: colors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${exam.completedTopics}/${exam.totalTopics} topics',
                    style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                  const SizedBox(width: EqTokens.space16),
                  Icon(Icons.timer_outlined, size: 14, color: colors.textSecondary),
                  const SizedBox(width: 4),
                  Text('${exam.remainingMinutes}m remaining',
                    style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Exam Detail Screen ────────────────────────────────────────────────────────

class ExamDetailScreen extends StatefulWidget {
  final Exam exam;
  const ExamDetailScreen({super.key, required this.exam});

  @override
  State<ExamDetailScreen> createState() => _ExamDetailScreenState();
}

class _ExamDetailScreenState extends State<ExamDetailScreen> {
  late Exam _exam;

  @override
  void initState() {
    super.initState();
    _exam = widget.exam;
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshExam());
  }

  Future<void> _refreshExam() async {
    final provider = context.read<ExamProvider>();
    await provider.fetchAll();
    final updated = provider.exams.firstWhere((e) => e.id == _exam.id, orElse: () => _exam);
    if (mounted) setState(() => _exam = updated);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final textTheme = context.eqText;
    final provider = context.read<ExamProvider>();
    final daysLeft = _exam.daysUntilExam;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(_exam.title, style: TextStyle(color: colors.textPrimary)),
        backgroundColor: colors.background,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _scheduleAllTopics(provider),
            icon: Icon(Icons.schedule, size: 16, color: colors.primary),
            label: Text('Schedule', style: TextStyle(color: colors.primary)),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'delete') _deleteExam(provider);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete Exam')),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(EqTokens.space24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Exam info card
            Container(
              padding: const EdgeInsets.all(EqTokens.space20),
              decoration: BoxDecoration(color: colors.surface, borderRadius: EqTokens.border16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(CupertinoIcons.calendar, color: colors.primary, size: 18),
                      const SizedBox(width: 8),
                      Text(DateFormat('EEEE, d MMMM yyyy').format(_exam.examDate),
                        style: textTheme.bodyMedium?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: EqTokens.space8),
                  Text(daysLeft < 0 ? 'Exam has passed'
                      : daysLeft == 0 ? '🔥 Exam is TODAY!'
                      : '$daysLeft days remaining',
                    style: textTheme.bodySmall?.copyWith(
                      color: daysLeft <= 3 && daysLeft >= 0 ? colors.warning : colors.textSecondary)),
                  if (_exam.topics.isNotEmpty) ...[
                    const SizedBox(height: EqTokens.space16),
                    ClipRRect(
                      borderRadius: EqTokens.border8,
                      child: LinearProgressIndicator(
                        value: _exam.coveragePercent / 100,
                        backgroundColor: colors.surfaceElevated,
                        color: colors.success,
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: EqTokens.space8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('${_exam.completedTopics}/${_exam.totalTopics} topics complete',
                          style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                        Text('${_exam.coveragePercent}% coverage',
                          style: textTheme.labelSmall?.copyWith(color: colors.success, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: EqTokens.space24),

            // Topics
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOPICS', style: textTheme.labelSmall?.copyWith(
                  color: colors.textSecondary, letterSpacing: 1.2)),
                FilledButton.icon(
                  onPressed: () => _showAddTopicSheet(provider),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Topic'),
                  style: FilledButton.styleFrom(
                    backgroundColor: colors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    textStyle: textTheme.labelSmall,
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space12),

            if (_exam.topics.isEmpty)
              Container(
                padding: const EdgeInsets.all(EqTokens.space24),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: colors.surface, borderRadius: EqTokens.border12),
                child: Text('Add topics to start planning your preparation',
                  style: textTheme.bodySmall?.copyWith(color: colors.textSecondary), textAlign: TextAlign.center),
              )
            else
              ..._exam.topics.map((topic) => _TopicTile(
                topic: topic,
                onComplete: (val) => provider.updateTopic(_exam.id, topic.id, {'isCompleted': val}),
                onDelete: () => provider.deleteTopic(_exam.id, topic.id).then((_) => _refreshExam()),
              )),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTopicSheet(ExamProvider provider) async {
    final titleCtrl = TextEditingController();
    int estimateMins = 60;
    String topicType = 'REVISION';

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.eqColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Add Topic', style: ctx.eqText.titleLarge?.copyWith(color: ctx.eqColors.textPrimary)),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Topic Name (e.g. Unit 3 — ER Diagrams)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: topicType,
                decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'REVISION', child: Text('Revision')),
                  DropdownMenuItem(value: 'PYQ', child: Text('PYQ Practice')),
                  DropdownMenuItem(value: 'MOCK_TEST', child: Text('Mock Test')),
                  DropdownMenuItem(value: 'LEARNING', child: Text('Learning')),
                  DropdownMenuItem(value: 'WEAK_TOPIC', child: Text('Weak Topic')),
                ],
                onChanged: (v) => setModal(() => topicType = v!),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Estimate: ', style: TextStyle(color: ctx.eqColors.textPrimary)),
                  Expanded(
                    child: Slider(
                      value: estimateMins.toDouble(),
                      min: 15, max: 180, divisions: 11,
                      label: '${estimateMins}m',
                      onChanged: (v) => setModal(() => estimateMins = v.round()),
                    ),
                  ),
                  Text('${estimateMins}m', style: TextStyle(color: ctx.eqColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () async {
                    if (titleCtrl.text.trim().isEmpty) return;
                    await provider.addTopic(_exam.id,
                      title: titleCtrl.text.trim(),
                      estimateMinutes: estimateMins,
                      confidence: 0.5,
                      topicType: topicType,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _refreshExam();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: ctx.eqColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(borderRadius: EqTokens.border12),
                  ),
                  child: const Text('Add Topic'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    titleCtrl.dispose();
  }

  Future<void> _scheduleAllTopics(ExamProvider provider) async {
    final result = await provider.scheduleTopics(_exam.id);
    if (result != null && mounted) {
      final count = result['tasksCreated'] as int? ?? 0;
      context.read<ScheduleProvider>().fetchDashboardData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$count preparation tasks added to your workload!'),
        backgroundColor: context.eqColors.success,
      ));
    }
  }

  Future<void> _deleteExam(ExamProvider provider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Exam?'),
        content: Text('Delete "${_exam.title}" and all its topics? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: context.eqColors.danger),
            child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await provider.deleteExam(_exam.id);
      if (mounted) Navigator.pop(context);
    }
  }
}

class _TopicTile extends StatelessWidget {
  final ExamTopic topic;
  final ValueChanged<bool> onComplete;
  final VoidCallback onDelete;

  const _TopicTile({required this.topic, required this.onComplete, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final textTheme = context.eqText;

    return Container(
      margin: const EdgeInsets.only(bottom: EqTokens.space8),
      padding: const EdgeInsets.symmetric(horizontal: EqTokens.space16, vertical: EqTokens.space12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: EqTokens.border12,
        border: topic.isCompleted ? Border.all(color: colors.success.withValues(alpha: 0.4)) : null,
      ),
      child: Row(
        children: [
          Checkbox(
            value: topic.isCompleted,
            onChanged: (v) => onComplete(v ?? false),
            activeColor: colors.success,
            shape: const CircleBorder(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(topic.title,
                  style: textTheme.bodySmall?.copyWith(
                    color: topic.isCompleted ? colors.textSecondary : colors.textPrimary,
                    decoration: topic.isCompleted ? TextDecoration.lineThrough : null,
                    fontWeight: FontWeight.w500,
                  )),
                Row(
                  children: [
                    Text(topic.topicTypeLabel,
                      style: textTheme.labelSmall?.copyWith(color: colors.primary)),
                    const Text(' · '),
                    Text('${topic.estimateMinutes}m',
                      style: textTheme.labelSmall?.copyWith(color: colors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, size: 18, color: colors.danger.withValues(alpha: 0.6)),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}
