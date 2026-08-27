import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import 'timeline_block.dart';
import '../forms/task_detail_sheet.dart';

class AbsoluteTimelineBlock extends StatelessWidget {
  final ScheduleBlock block;
  final DateTime displayStart;
  final int displayDurationMinutes;
  final double pixelsPerMinute;
  final Task? task;

  const AbsoluteTimelineBlock({
    super.key,
    required this.block,
    required this.displayStart,
    required this.displayDurationMinutes,
    required this.pixelsPerMinute,
    this.task,
  });

  @override
  Widget build(BuildContext context) {
    final startMinutes = displayStart.hour * 60 + displayStart.minute;
    final top = startMinutes * pixelsPerMinute;
    final height = displayDurationMinutes * pixelsPerMinute;

    return Positioned(
      top: top,
      left: 58,
      right: EqTokens.space16,
      height: height,
      child: Semantics(
        label: _getSemanticLabel(),
        button: task != null,
        child: GestureDetector(
          onTap: () {
            if (task != null) {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => TaskDetailSheet(task: task!),
              );
            }
          },
          child: _buildInnerBlock(context),
        ),
      ),
    );
  }

  String _getSemanticLabel() {
    final type = block.type;
    final isLocked = block.isLocked ? "Completed" : "Scheduled";
    final title = task != null ? task!.title : type;
    return "$isLocked $type block: $title, from ${displayStart.hour}:${displayStart.minute} for $displayDurationMinutes minutes.";
  }

  Widget _buildInnerBlock(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    BlockType type;
    switch (block.type) {
      case 'FIXED':
        type = BlockType.fixed;
        break;
      case 'BREAK':
        type = BlockType.breakTime;
        break;
      case 'FREE':
        type = BlockType.free;
        break;
      default:
        type = BlockType.task;
    }

    Color bgColor;
    Color fgColor;
    Color borderColor;
    
    if (type == BlockType.task) {
      bgColor = block.isLocked ? colors.statusCompleted.withOpacity(0.1) : colors.primary.withOpacity(0.05);
      fgColor = block.isLocked ? colors.statusCompleted : colors.primary;
      borderColor = block.isLocked ? colors.statusCompleted.withOpacity(0.3) : colors.primary.withOpacity(0.2);
    } else if (type == BlockType.fixed) {
      bgColor = colors.warning.withOpacity(0.1);
      fgColor = colors.warning;
      borderColor = colors.warning.withOpacity(0.3);
    } else if (type == BlockType.breakTime) {
      bgColor = colors.energyMedium.withOpacity(0.1);
      fgColor = colors.energyMedium;
      borderColor = colors.energyMedium.withOpacity(0.3);
    } else {
      bgColor = Colors.transparent;
      fgColor = colors.textSecondary;
      borderColor = colors.surfaceElevated;
    }

    String title = 'Task';
    if (block.taskId != null) {
      title = 'Task ${block.taskId!.length > 4 ? block.taskId!.substring(0, 4) : block.taskId}';
    }
    if (task != null) {
      title = task!.title;
    } else if (type == BlockType.fixed) {
      title = 'Fixed Commitment';
    } else if (type == BlockType.breakTime) {
      title = 'Break';
    } else if (type == BlockType.free) {
      title = 'Available Capacity';
    }

    final start = '${displayStart.hour.toString().padLeft(2, '0')}:${displayStart.minute.toString().padLeft(2, '0')}';
    final end = '${block.endTime.hour.toString().padLeft(2, '0')}:${block.endTime.minute.toString().padLeft(2, '0')}';
    
    // Show original duration context even if split for rendering
    final durationSuffix = block.durationMinutes != displayDurationMinutes ? ' (Cont.)' : '';
    final timeRange = '$start → $end$durationSuffix';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EqTokens.space12, vertical: EqTokens.space8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: EqTokens.border8,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 4,
            height: double.infinity,
            decoration: BoxDecoration(
              color: fgColor,
              borderRadius: EqTokens.border4,
            ),
          ),
          const SizedBox(width: EqTokens.space12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text.bodyMedium?.copyWith(
                    color: fgColor,
                    fontWeight: FontWeight.w600,
                    decoration: block.isLocked ? TextDecoration.lineThrough : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  timeRange,
                  style: text.bodySmall?.copyWith(color: fgColor.withOpacity(0.8)),
                ),
                if (task != null && displayDurationMinutes >= 45) ...[
                  const Spacer(),
                  Row(
                    children: [
                      Icon(Icons.psychology, size: 14, color: fgColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        task!.cognitiveLoad.name.toUpperCase(),
                        style: text.labelSmall?.copyWith(color: fgColor.withOpacity(0.7)),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.hourglass_bottom, size: 14, color: fgColor.withOpacity(0.7)),
                      const SizedBox(width: 4),
                      Text(
                        '${block.durationMinutes}m chunk',
                        style: text.labelSmall?.copyWith(color: fgColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
