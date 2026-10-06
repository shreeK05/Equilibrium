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

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: ratio),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CircularProgressIndicator(
                    value: 1.0,
                    strokeWidth: 6,
                    color: colors.surfaceElevated,
                  ),
                  CircularProgressIndicator(
                    value: value,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: indicatorColor,
                  ),
                  Center(
                    child: Text(
                      '${(value * 100).toInt()}%',
                      style: text.titleMedium?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: EqTokens.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$plannedStr planned',
                    style: text.titleSmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$remainingStr remaining capacity',
                    style: text.bodySmall?.copyWith(color: colors.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        );
      },
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
