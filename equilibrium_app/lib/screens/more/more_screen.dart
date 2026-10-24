import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/state/exam_provider.dart';
import '../../core/state/profile_provider.dart';
import '../commitments/commitments_screen.dart';
import '../exams/exams_screen.dart';
import '../analytics/analytics_screen.dart';
import '../profile/profile_screen.dart';
import '../imports/syllabus_import_screen.dart';
import '../imports/ics_import_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Scaffold(
      backgroundColor: colors.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                EqTokens.space24,
                EqTokens.space24,
                EqTokens.space24,
                EqTokens.space12,
              ),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MORE TOOLS',
                      style: text.labelSmall?.copyWith(
                        color: colors.textSecondary,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ).animate().fade().slideY(begin: -0.2),
                    const SizedBox(height: EqTokens.space8),
                    Text(
                      'Academic & Tools',
                      style: text.headlineLarge?.copyWith(
                        color: colors.textPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ).animate().fade(delay: 80.ms).slideY(begin: -0.2),
                    const SizedBox(height: EqTokens.space4),
                    Text(
                      'Manage fixed commitments, exams, analytics, and imports',
                      style: text.bodyMedium?.copyWith(
                        color: colors.textSecondary,
                      ),
                    ).animate().fade(delay: 120.ms),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: EqTokens.space24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: EqTokens.space12),
                  _buildSectionHeader(context, 'ACADEMIC & SCHEDULE'),
                  const SizedBox(height: EqTokens.space12),

                  // Commitments (renamed from Locked)
                  Consumer<ScheduleProvider>(
                    builder: (context, scheduleProvider, _) {
                      final count = scheduleProvider.commitments.length;
                      return _MoreCardItem(
                        icon: CupertinoIcons.calendar_badge_plus,
                        iconColor: colors.commitment,
                        title: 'Fixed Commitments',
                        subtitle: 'Lectures, labs, study halls & recurring events',
                        badgeText: count > 0 ? '$count active' : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CommitmentsScreen()),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: EqTokens.space12),

                  // Exams Screen
                  Consumer<ExamProvider>(
                    builder: (context, examProvider, _) {
                      final count = examProvider.exams.length;
                      return _MoreCardItem(
                        icon: CupertinoIcons.book,
                        iconColor: colors.primary,
                        title: 'Exam Preparation',
                        subtitle: 'Upcoming exam milestones, review tracks & pacing',
                        badgeText: count > 0 ? '$count tracks' : null,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ExamsScreen()),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: EqTokens.space24),

                  _buildSectionHeader(context, 'DATA & IMPORTS'),
                  const SizedBox(height: EqTokens.space12),

                  // Import Syllabus
                  _MoreCardItem(
                    icon: CupertinoIcons.doc_text_viewfinder,
                    iconColor: colors.energyPeak,
                    title: 'Import Syllabus PDF',
                    subtitle: 'Extract course assignments and test dates with AI',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SyllabusImportScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: EqTokens.space12),

                  // Import Calendar (ICS)
                  _MoreCardItem(
                    icon: CupertinoIcons.arrow_down_doc,
                    iconColor: colors.workload,
                    title: 'Import Academic Calendar (.ics)',
                    subtitle: 'Sync university timetable and academic schedule',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const IcsImportScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: EqTokens.space24),

                  _buildSectionHeader(context, 'INSIGHTS & ACCOUNT'),
                  const SizedBox(height: EqTokens.space12),

                  // Analytics / Workload Insights
                  _MoreCardItem(
                    icon: CupertinoIcons.chart_bar_alt_fill,
                    iconColor: colors.success,
                    title: 'Workload & Capacity Analytics',
                    subtitle: 'Weekly study distribution, sleep protection & pace',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AnalyticsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: EqTokens.space12),

                  // Profile & Constraints
                  Consumer<ProfileProvider>(
                    builder: (context, profileProvider, _) {
                      final name = profileProvider.profile?.name ?? 'Student Settings';
                      return _MoreCardItem(
                        icon: CupertinoIcons.person_crop_circle,
                        iconColor: colors.textSecondary,
                        title: 'Profile & Sleep Constraints',
                        subtitle: '$name • Protected sleep hours & preferences',
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ProfileScreen()),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: EqTokens.space40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Text(
      title,
      style: text.labelSmall?.copyWith(
        color: colors.textSecondary,
        letterSpacing: 1.0,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _MoreCardItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badgeText;
  final VoidCallback onTap;

  const _MoreCardItem({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.badgeText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;

    return Semantics(
      button: true,
      label: '$title: $subtitle',
      child: Material(
        color: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: EqTokens.border16,
          side: BorderSide(color: colors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          borderRadius: EqTokens.border16,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: EqTokens.space16,
              vertical: EqTokens.space14,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: EqTokens.border12,
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: EqTokens.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: text.titleMedium?.copyWith(
                                color: colors.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: EqTokens.space8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: EqTokens.space8,
                                vertical: EqTokens.space2,
                              ),
                              decoration: BoxDecoration(
                                color: iconColor.withValues(alpha: 0.15),
                                borderRadius: EqTokens.border8,
                              ),
                              child: Text(
                                badgeText!,
                                style: text.labelSmall?.copyWith(
                                  color: iconColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: EqTokens.space4),
                      Text(
                        subtitle,
                        style: text.bodySmall?.copyWith(
                          color: colors.textSecondary,
                          fontSize: 13,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: EqTokens.space8),
                Icon(
                  CupertinoIcons.chevron_forward,
                  size: 16,
                  color: colors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
