import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class WorkloadMeter extends StatelessWidget {
  final int plannedMinutes;
  final int availableMinutes;

  const WorkloadMeter({
    super.key,
    required this.plannedMinutes,
    required this.availableMinutes,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    double ratio = availableMinutes > 0 ? (plannedMinutes / availableMinutes) : 0;
    if (ratio > 1.0) ratio = 1.0;
    if (ratio < 0.0) ratio = 0.0;

    final int remaining = availableMinutes - plannedMinutes;
    final String remainingStr = remaining > 0 ? _formatMinutes(remaining) : '0m';
    final String plannedStr = _formatMinutes(plannedMinutes);

    Color indicatorColor = colors.workload;
    if (ratio >= 0.9) {
      indicatorColor = colors.warning; // Near capacity
    }
    if (ratio == 1.0 && availableMinutes > 0) {
      indicatorColor = colors.danger; // At capacity
    }
    if (plannedMinutes == 0) {
      indicatorColor = colors.success; // Zero workload
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$plannedStr planned', style: text.bodyMedium?.copyWith(color: colors.textPrimary)),
            Text('$remainingStr remaining', style: text.bodyMedium?.copyWith(color: colors.textSecondary)),
          ],
        ),
        const SizedBox(height: EqTokens.space12),
        ClipRRect(
          borderRadius: EqTokens.border4,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: colors.surfaceElevated,
            valueColor: AlwaysStoppedAnimation<Color>(indicatorColor),
          ),
        ),
      ],
    );
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes == 0) return '0m';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours > 0 && mins > 0) return '${hours}h ${mins}m';
    if (hours > 0) return '${hours}h';
    return '${mins}m';
  }
}
