import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../models/schedule.dart';

class AbsoluteSleepShield extends StatelessWidget {
  final ScheduleBlock block;
  final DateTime displayStart;
  final int displayDurationMinutes;
  final double pixelsPerMinute;

  const AbsoluteSleepShield({
    super.key,
    required this.block,
    required this.displayStart,
    required this.displayDurationMinutes,
    required this.pixelsPerMinute,
  });

  @override
  Widget build(BuildContext context) {
    final startMinutes = displayStart.hour * 60 + displayStart.minute;
    final top = startMinutes * pixelsPerMinute;
    final height = displayDurationMinutes * pixelsPerMinute;

    final startStr = '${displayStart.hour.toString().padLeft(2, '0')}:${displayStart.minute.toString().padLeft(2, '0')}';
    final endStr = '${block.endTime.hour.toString().padLeft(2, '0')}:${block.endTime.minute.toString().padLeft(2, '0')}';
    
    // In Flutter, true hatching requires a CustomPainter, but we can approximate a shield
    // with a translucent overlay and dotted borders for a premium feel.
    
    return Positioned(
      top: top,
      left: 58,
      right: EqTokens.space16,
      height: height,
      child: Semantics(
        label: 'Sleep block from $startStr for $displayDurationMinutes minutes',
        child: Container(
          padding: const EdgeInsets.all(EqTokens.space12),
          decoration: BoxDecoration(
            color: context.eqColors.surfaceElevated.withOpacity(0.5),
            borderRadius: EqTokens.border8,
            border: Border.all(
              color: context.eqColors.textSecondary.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.nights_stay,
                size: 16,
                color: context.eqColors.textSecondary,
              ),
              const SizedBox(width: EqTokens.space8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sleep Shield',
                      style: context.eqText.labelLarge?.copyWith(
                        color: context.eqColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (displayDurationMinutes >= 60)
                      Text(
                        '$startStr → $endStr',
                        style: context.eqText.labelSmall?.copyWith(
                          color: context.eqColors.textSecondary.withOpacity(0.8),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
