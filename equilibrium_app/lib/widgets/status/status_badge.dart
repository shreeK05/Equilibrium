import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

enum EqStatus {
  scheduled,
  partiallyScheduled,
  deferred,
  completed,
  protected,
}

class StatusBadge extends StatelessWidget {
  final EqStatus status;

  const StatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    Color bgColor;
    Color fgColor;
    String label;
    IconData? icon;

    switch (status) {
      case EqStatus.scheduled:
        bgColor = colors.primary.withOpacity(0.1);
        fgColor = colors.primary;
        label = 'SCHEDULED';
        icon = Icons.check_circle_outline;
        break;
      case EqStatus.partiallyScheduled:
        bgColor = colors.workload.withOpacity(0.1);
        fgColor = colors.workload;
        label = 'PARTIALLY SCHEDULED';
        icon = Icons.timelapse;
        break;
      case EqStatus.deferred:
        bgColor = colors.statusDeferred.withOpacity(0.1);
        fgColor = colors.statusDeferred;
        label = 'DEFERRED';
        icon = Icons.next_plan_outlined;
        break;
      case EqStatus.completed:
        bgColor = colors.statusCompleted.withOpacity(0.1);
        fgColor = colors.statusCompleted;
        label = 'COMPLETED';
        icon = Icons.done_all;
        break;
      case EqStatus.protected:
        bgColor = colors.sleepShieldMuted;
        fgColor = colors.sleepShield;
        label = 'PROTECTED';
        icon = Icons.shield_outlined;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: EqTokens.space8, vertical: EqTokens.space4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: EqTokens.border4,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fgColor),
            const SizedBox(width: EqTokens.space4),
          ],
          Text(
            label,
            style: text.labelSmall?.copyWith(color: fgColor, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
