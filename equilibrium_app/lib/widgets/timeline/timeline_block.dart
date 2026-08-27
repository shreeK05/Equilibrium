import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

enum BlockType { task, fixed, breakTime, free }

class TimelineBlock extends StatelessWidget {
  final String title;
  final String timeRange;
  final BlockType type;
  final bool isCompleted;

  const TimelineBlock({
    super.key,
    required this.title,
    required this.timeRange,
    required this.type,
    this.isCompleted = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    Color bgColor;
    Color fgColor;
    Color borderColor;
    
    switch (type) {
      case BlockType.task:
        bgColor = isCompleted ? colors.statusCompleted.withOpacity(0.1) : colors.primary.withOpacity(0.05);
        fgColor = isCompleted ? colors.statusCompleted : colors.primary;
        borderColor = isCompleted ? colors.statusCompleted.withOpacity(0.3) : colors.primary.withOpacity(0.2);
        break;
      case BlockType.fixed:
        bgColor = colors.warning.withOpacity(0.1);
        fgColor = colors.warning;
        borderColor = colors.warning.withOpacity(0.3);
        break;
      case BlockType.breakTime:
        bgColor = colors.energyMedium.withOpacity(0.1);
        fgColor = colors.energyMedium;
        borderColor = colors.energyMedium.withOpacity(0.3);
        break;
      case BlockType.free:
        bgColor = Colors.transparent;
        fgColor = colors.textSecondary;
        borderColor = colors.surfaceElevated;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: EqTokens.space8),
      padding: const EdgeInsets.all(EqTokens.space12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: EqTokens.border8,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
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
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                Text(
                  timeRange,
                  style: text.bodySmall?.copyWith(color: fgColor.withOpacity(0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
