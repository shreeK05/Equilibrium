import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../widgets/status/empty_state.dart';

class CommitmentsScreen extends StatelessWidget {
  const CommitmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(EqTokens.space24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HARD CONSTRAINTS',
                  style: text.labelSmall?.copyWith(
                    color: colors.textSecondary,
                    letterSpacing: 1.2,
                  ),
                ).animate().fade().slideY(begin: -0.2),
                const SizedBox(height: EqTokens.space8),
                Text(
                  'Fixed Commitments',
                  style: text.headlineLarge?.copyWith(
                    color: colors.textPrimary,
                  ),
                ).animate().fade(delay: 100.ms).slideY(begin: -0.2),
              ],
            ),
          ),
          
          Expanded(
            child: Consumer<ScheduleProvider>(
              builder: (context, provider, child) {
                final commitments = provider.commitments;
                
                if (commitments.isEmpty) {
                  return const Center(
                    child: EmptyStateWidget(
                      title: 'No fixed commitments',
                      message: 'Add classes, labs, or exams to lock their time in your schedule.',
                      icon: Icons.event_available,
                    ),
                  ).animate().fade();
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: EqTokens.space24),
                  itemCount: commitments.length,
                  separatorBuilder: (context, index) => const SizedBox(height: EqTokens.space16),
                  itemBuilder: (context, index) {
                    final c = commitments[index];
                    return Dismissible(
                      key: Key(c.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 24),
                        decoration: BoxDecoration(
                          color: context.eqColors.danger,
                          borderRadius: EqTokens.border16,
                        ),
                        child: Icon(Icons.delete_outline, color: context.eqColors.surface),
                      ),
                      onDismissed: (direction) {
                        provider.deleteCommitment(c.id);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(EqTokens.space24),
                        decoration: BoxDecoration(
                          color: colors.surface,
                          borderRadius: EqTokens.border16,
                          border: Border.all(color: colors.primary.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colors.surfaceElevated,
                                borderRadius: EqTokens.border12,
                              ),
                              child: Icon(
                                c.type.name == 'class_' ? Icons.school : c.type.name == 'lab' ? Icons.science : Icons.event,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: EqTokens.space16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(c.title, style: text.titleMedium?.copyWith(color: colors.textPrimary)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${DateFormat('MMM d').format(c.startTime)} • ${DateFormat('h:mm a').format(c.startTime)} - ${DateFormat('h:mm a').format(c.endTime)}',
                                    style: text.bodyMedium?.copyWith(color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ).animate().fade(delay: (index * 50).ms).slideX(begin: 0.1),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
