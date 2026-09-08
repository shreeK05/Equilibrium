import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../models/task.dart';
import 'explanation_sheet.dart';

class TaskDetailSheet extends StatefulWidget {
  final Task task;

  const TaskDetailSheet({super.key, required this.task});

  @override
  State<TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<TaskDetailSheet> {
  late double _progressValue;
  String? _newTitle;
  String? _newDesc;
  String? _newCategory;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _progressValue = widget.task.completedMinutes.toDouble();
  }

  void _saveProgress() async {
    final provider = context.read<ScheduleProvider>();
    final actualMinutes = _progressValue.toInt();
    
    final updates = <String, dynamic>{
      'completedMinutes': actualMinutes,
    };
    if (_newTitle != null && _newTitle!.trim().isNotEmpty) updates['title'] = _newTitle!.trim();
    if (_newDesc != null) updates['description'] = _newDesc!.trim();
    if (_newCategory != null) updates['category'] = _newCategory!.trim();

    final success = actualMinutes >= widget.task.estimateMinutes
        ? await provider.completeTask(widget.task.id, actualMinutes)
        : await provider.updateTask(widget.task.id, updates);

    if (success && mounted) {
      Navigator.pop(context);
    }
  }

  void _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Responsibility'),
        content: const Text('This task will be removed from future scheduling. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: context.eqColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<ScheduleProvider>();
      final success = await provider.deleteTask(widget.task.id);
      if (success && mounted) Navigator.pop(context);
    }
  }

  Future<void> _splitTask() async {
    final parts = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Split into focus blocks'),
        children: [2, 3, 4, 5, 6].map((value) => SimpleDialogOption(
          onPressed: () => Navigator.pop(context, value),
          child: Text('$value parts'),
        )).toList(),
      ),
    );
    if (parts == null || !mounted) return;
    final success = await context.read<ScheduleProvider>().splitTask(widget.task.id, parts);
    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return Container(
      padding: EdgeInsets.only(
        left: EqTokens.space24,
        right: EqTokens.space24,
        top: EqTokens.space24,
        bottom: MediaQuery.of(context).viewInsets.bottom + EqTokens.space24,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: widget.task.title),
                    onChanged: (val) {
                      _newTitle = val;
                      setState(() => _isEditing = true);
                    },
                    style: text.headlineMedium?.copyWith(color: colors.textPrimary),
                    decoration: const InputDecoration(border: InputBorder.none, hintText: 'Task Title'),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: colors.danger),
                  onPressed: _delete,
                )
              ],
            ),

            TextField(
              controller: TextEditingController(text: widget.task.description),
              onChanged: (val) {
                _newDesc = val;
                setState(() => _isEditing = true);
              },
              maxLines: null,
              style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Add a description...',
                hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(height: EqTokens.space12),

            Row(
              children: [
                if (widget.task.subjectName != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: EqTokens.border8,
                    ),
                    child: Text(widget.task.subjectName!,
                      style: text.labelSmall?.copyWith(color: colors.primary)),
                  ),
                  const SizedBox(width: EqTokens.space8),
                ],
                Expanded(
                  child: TextField(
                    controller: TextEditingController(text: widget.task.category),
                    onChanged: (val) {
                      _newCategory = val;
                      setState(() => _isEditing = true);
                    },
                    style: text.bodySmall?.copyWith(color: colors.textPrimary),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Category (e.g. Reading)',
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: EqTokens.space24),
            
            _buildInfoGrid(context),
            const SizedBox(height: EqTokens.space24),
            
            Text('Record Progress', style: text.labelSmall?.copyWith(color: colors.textSecondary)),
            const SizedBox(height: EqTokens.space16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_progressValue.toInt()}m completed', style: text.bodyMedium?.copyWith(color: colors.success)),
                Text('${widget.task.estimateMinutes - _progressValue.toInt()}m remaining', style: text.bodyMedium?.copyWith(color: colors.textSecondary)),
              ],
            ),
            Slider(
              value: _progressValue,
              min: 0,
              max: widget.task.estimateMinutes.toDouble(),
              divisions: widget.task.estimateMinutes > 0 ? widget.task.estimateMinutes : 1,
              activeColor: colors.success,
              onChanged: (val) => setState(() {
                _progressValue = val;
                _isEditing = true;
              }),
            ),
            
            const SizedBox(height: EqTokens.space32),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: widget.task.remainingMinutes >= 2 ? _splitTask : null,
                icon: const Icon(Icons.call_split),
                label: const Text('Split into focus blocks'),
              ),
            ),
            const SizedBox(height: EqTokens.space16),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: Icon(Icons.psychology, color: colors.primary),
                label: Text('Why was this scheduled?', style: text.labelLarge?.copyWith(color: colors.primary)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(EqTokens.space16),
                  side: BorderSide(color: colors.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                onPressed: () {
                  final provider = context.read<ScheduleProvider>();
                  final versionId = provider.currentSchedule?.id;
                  
                  if (versionId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('No schedule available to explain.')),
                    );
                    return;
                  }

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => ExplanationSheet(
                      task: widget.task,
                      versionId: versionId,
                    ),
                  );
                },
              ),
            ),
            
            const SizedBox(height: EqTokens.space16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isEditing ? _saveProgress : () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.surface,
                  padding: const EdgeInsets.all(EqTokens.space16),
                  shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
                ),
                child: context.watch<ScheduleProvider>().isLoading
                    ? SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: colors.surface, strokeWidth: 2))
                    : Text(_isEditing ? 'Save Changes' : 'Close', style: text.labelLarge?.copyWith(color: colors.surface)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    final colors = context.eqColors;
    final provider = context.watch<ScheduleProvider>();
    
    int scheduledMinutes = 0;
    if (provider.currentSchedule != null) {
      for (var b in provider.currentSchedule!.blocks) {
        if (b.taskId == widget.task.id) {
          scheduledMinutes += b.durationMinutes;
        }
      }
    }

    final deadlineStr = DateFormat('MMM d, h:mm a').format(widget.task.deadline);
    final isFlexible = widget.task.deadlineType.name.toUpperCase() == 'FLEXIBLE';

    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: EqTokens.border8,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(context, 'Scheduled', '${scheduledMinutes}m', Icons.schedule),
              _buildMetric(context, 'Deadline', deadlineStr, Icons.event, 
                  subtitle: isFlexible ? 'Flexible' : 'Hard deadline',
                  subtitleColor: isFlexible ? colors.primary : colors.danger),
            ],
          ),
          const SizedBox(height: EqTokens.space16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(context, 'Status', widget.task.status.name.toUpperCase(), Icons.info_outline),
              _buildMetric(context, 'Load', widget.task.cognitiveLoad.name.toUpperCase(), Icons.psychology_alt),
            ],
          ),
          if (provider.currentSchedule != null) ...[
            const Divider(height: EqTokens.space24),
            Row(
              children: [
                Icon(Icons.info_outline, size: 14, color: colors.textSecondary),
                const SizedBox(width: EqTokens.space8),
                Text(
                  'Active Schedule: ${provider.currentSchedule!.id.substring(0, 8)}',
                  style: context.eqText.bodySmall?.copyWith(color: colors.textSecondary),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon, {String? subtitle, Color? subtitleColor}) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: colors.textSecondary),
            const SizedBox(width: 4),
            Text(label, style: text.labelSmall?.copyWith(color: colors.textSecondary)),
          ],
        ),
        const SizedBox(height: 4),
        Text(value, style: text.labelLarge?.copyWith(color: colors.textPrimary)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle, style: text.labelSmall?.copyWith(color: subtitleColor ?? colors.textSecondary, fontSize: 10)),
        ],
      ],
    );
  }
}
