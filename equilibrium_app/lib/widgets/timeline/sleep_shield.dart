import 'package:flutter/material.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';

class SleepShield extends StatelessWidget {
  final String startTime;
  final String endTime;
  final String durationStr;

  const SleepShield({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.durationStr,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 290;
        return Container(
          padding: const EdgeInsets.all(EqTokens.space16),
          decoration: BoxDecoration(
            color: colors.sleepShieldMuted,
            borderRadius: EqTokens.border12,
            border: Border.all(color: colors.sleepShield.withValues(alpha: 0.2)),
          ),
          child: isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(EqTokens.space8),
                          decoration: BoxDecoration(
                            color: colors.sleepShield.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.shield_moon_outlined, color: colors.sleepShield),
                        ),
                        const SizedBox(width: EqTokens.space12),
                        Expanded(
                          child: Text(
                            'Sleep Shield',
                            style: text.titleMedium?.copyWith(color: colors.sleepShield, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: EqTokens.space8),
                    Text(
                      'Your resting period is mathematically protected.',
                      style: text.bodySmall?.copyWith(color: colors.sleepShield.withValues(alpha: 0.8)),
                    ),
                    const SizedBox(height: EqTokens.space8),
                    Wrap(
                      spacing: EqTokens.space8,
                      runSpacing: EqTokens.space4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          '$startTime → $endTime',
                          style: text.labelLarge?.copyWith(color: colors.sleepShield, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          durationStr,
                          style: text.bodySmall?.copyWith(color: colors.sleepShield.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(EqTokens.space8),
                      decoration: BoxDecoration(
                        color: colors.sleepShield.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.shield_moon_outlined, color: colors.sleepShield),
                    ),
                    const SizedBox(width: EqTokens.space16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sleep Shield',
                            style: text.titleMedium?.copyWith(color: colors.sleepShield, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your resting period is mathematically protected.',
                            style: text.bodySmall?.copyWith(color: colors.sleepShield.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: EqTokens.space12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$startTime → $endTime',
                          style: text.labelLarge?.copyWith(color: colors.sleepShield, fontWeight: FontWeight.w600),
                        ),
                        Text(
                          durationStr,
                          style: text.bodySmall?.copyWith(color: colors.sleepShield.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }
}
