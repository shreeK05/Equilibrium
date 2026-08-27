import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _progressValue = widget.task.completedMinutes.toDouble();
  }

  void _saveProgress() async {
    final provider = context.read<ScheduleProvider>();
    final success = await provider.updateTask(widget.task.id, {
      if (_newTitle != null && _newTitle!.trim().isNotEmpty) 'title': _newTitle!.trim(),
      'completedMinutes': _progressValue.toInt(),
    });

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
                  onChanged: (val) => _newTitle = val,
                  style: text.headlineMedium?.copyWith(color: colors.textPrimary),
                  decoration: const InputDecoration(border: InputBorder.none),
                ),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline, color: colors.danger),
                onPressed: _delete,
              )
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
            onChanged: (val) => setState(() => _progressValue = val),
          ),
          
          const SizedBox(height: EqTokens.space32),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: Icon(Icons.psychology, color: colors.primary),
              label: Text('Why was this scheduled?', style: text.labelLarge?.copyWith(color: colors.primary)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.all(EqTokens.space16),
                side: BorderSide(color: colors.primary.withOpacity(0.5)),
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
              onPressed: _saveProgress,
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary,
                foregroundColor: colors.surface,
                padding: const EdgeInsets.all(EqTokens.space16),
                shape: RoundedRectangleBorder(borderRadius: EqTokens.border8),
              ),
              child: Text('Update Workload', style: text.labelLarge?.copyWith(color: colors.surface)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoGrid(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    final provider = context.watch<ScheduleProvider>();
    
    int scheduledMinutes = 0;
    if (provider.currentSchedule != null) {
      for (var b in provider.currentSchedule!.blocks) {
        if (b.taskId == widget.task.id) {
          scheduledMinutes += b.durationMinutes;
        }
      }
    }

    final deadlineStr = "${widget.task.deadline.month}/${widget.task.deadline.day} ${widget.task.deadline.hour.toString().padLeft(2, '0')}:${widget.task.deadline.minute.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(EqTokens.space16),
      decoration: BoxDecoration(
        color: colors.primary.withOpacity(0.05),
        borderRadius: EqTokens.border8,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMetric(context, 'Scheduled', '${scheduledMinutes}m', Icons.schedule),
              _buildMetric(context, 'Deadline', deadlineStr, Icons.event),
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
                  'Active Schedule Version: ${provider.currentSchedule!.id.substring(0, 8)}',
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                )
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildMetric(BuildContext context, String label, String value, IconData icon) {
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
      ],
    );
  }
}
