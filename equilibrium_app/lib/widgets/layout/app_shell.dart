import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../core/theme/tokens.dart';
import '../../screens/today/today_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../screens/tasks/tasks_screen.dart';
import '../../screens/more/more_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/timer/timer_screen.dart';
import '../forms/create_task_sheet.dart';
import '../forms/create_commitment_sheet.dart';
import '../../screens/imports/syllabus_import_screen.dart';
import '../../screens/imports/ics_import_screen.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/state/profile_provider.dart';
import '../../core/state/timer_provider.dart';
import '../../core/api/api_client.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    TodayScreen(),
    ScheduleScreen(),
    TasksScreen(),
    MoreScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    final tabTitles = ['Today', 'Plan', 'Tasks', 'More'];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          tabTitles[_currentIndex],
          style: TextStyle(
            color: colors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: false,
        actions: [
          // Timer FAB shortcut in app bar
          Consumer<TimerProvider>(
            builder: (ctx, timer, _) {
              if (timer.timerState != TimerState.idle) {
                return GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: timer.timerState == TimerState.running
                          ? colors.primary.withValues(alpha: 0.15)
                          : colors.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: timer.timerState == TimerState.running ? colors.primary : colors.warning,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          timer.timerState == TimerState.running ? Icons.timer : Icons.pause_circle_outline,
                          size: 14,
                          color: timer.timerState == TimerState.running ? colors.primary : colors.warning,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          timer.displayTime,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: timer.timerState == TimerState.running ? colors.primary : colors.warning,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
          if (_currentIndex == 0 || _currentIndex == 1)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
              onPressed: () {
                context.read<ScheduleProvider>().fetchDashboardData();
              },
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
              },
              child: Consumer<ProfileProvider>(
                builder: (context, profileProvider, child) {
                  final name = profileProvider.profile?.name;
                  final initial = (name != null && name.isNotEmpty)
                      ? name[0].toUpperCase()
                      : 'E';
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: _screens[_currentIndex],
          ),
          Positioned(
            bottom: EqTokens.space16,
            left: EqTokens.space24,
            child: ValueListenableBuilder<bool>(
              valueListenable: context.read<ApiClient>().isOffline,
              builder: (context, isOffline, child) {
                if (!isOffline) return const SizedBox.shrink();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colors.surfaceElevated,
                    borderRadius: EqTokens.border12,
                    border: Border.all(color: colors.textSecondary.withValues(alpha: 0.2)),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cloud_off, size: 14, color: colors.textSecondary),
                      const SizedBox(width: EqTokens.space8),
                      Text('Working offline', style: TextStyle(fontSize: 12, color: colors.textSecondary, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ).animate().fade().slideY(begin: 0.5);
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.cardBorder, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: colors.surface,
          selectedItemColor: colors.primary,
          unselectedItemColor: colors.textSecondary,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.sun_max),
              activeIcon: Icon(CupertinoIcons.sun_max_fill),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.calendar),
              activeIcon: Icon(CupertinoIcons.calendar_today),
              label: 'Plan',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.list_bullet),
              activeIcon: Icon(CupertinoIcons.list_bullet_indent),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.square_grid_2x2),
              activeIcon: Icon(CupertinoIcons.square_grid_2x2_fill),
              label: 'More',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAdd(context),
        backgroundColor: colors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Quick Add',
        child: const Icon(Icons.add),
      ).animate().scale(delay: 200.ms, duration: 250.ms, curve: Curves.easeOutBack),
    );
  }

  void _showQuickAdd(BuildContext context) {
    final colors = context.eqColors;
    final text = context.eqText;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(EqTokens.radius24)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            EqTokens.space24,
            EqTokens.space16,
            EqTokens.space24,
            EqTokens.space24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: EqTokens.border4,
                  ),
                ),
              ),
              const SizedBox(height: EqTokens.space16),
              Text(
                'Quick Add',
                style: text.titleLarge?.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: EqTokens.space4),
              Text(
                'What would you like to schedule or capture?',
                style: text.bodySmall?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: EqTokens.space20),
              _buildQuickAddTile(
                context,
                icon: CupertinoIcons.checkmark_circle,
                iconColor: colors.primary,
                title: 'Add Responsibility',
                subtitle: 'A study assignment, lab record, or prep task',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreateTaskSheet(),
                  );
                },
              ),
              const SizedBox(height: EqTokens.space8),
              _buildQuickAddTile(
                context,
                icon: CupertinoIcons.timer,
                iconColor: colors.energyMedium,
                title: 'Start Focus Session',
                subtitle: 'Begin a timed study block with sleep protection',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
                },
              ),
              const SizedBox(height: EqTokens.space8),
              _buildQuickAddTile(
                context,
                icon: CupertinoIcons.calendar_badge_plus,
                iconColor: colors.commitment,
                title: 'Fixed Commitment',
                subtitle: 'Lecture, lab, routine, or standing appointment',
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => const CreateCommitmentSheet(),
                  );
                },
              ),
              const SizedBox(height: EqTokens.space8),
              _buildQuickAddTile(
                context,
                icon: CupertinoIcons.doc_text_viewfinder,
                iconColor: colors.energyPeak,
                title: 'Import Syllabus PDF',
                subtitle: 'Extract deadlines and deliverables from course outline',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SyllabusImportScreen()));
                },
              ),
              const SizedBox(height: EqTokens.space8),
              _buildQuickAddTile(
                context,
                icon: CupertinoIcons.arrow_down_doc,
                iconColor: colors.workload,
                title: 'Import Calendar (.ics)',
                subtitle: 'Import timetable from university calendar file',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const IcsImportScreen()));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAddTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final colors = context.eqColors;
    final text = context.eqText;
    return Material(
      color: colors.surfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: EqTokens.border12,
        side: BorderSide(color: colors.cardBorder),
      ),
      child: ListTile(
        shape: const RoundedRectangleBorder(borderRadius: EqTokens.border12),
        leading: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: EqTokens.border8,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: text.titleSmall?.copyWith(color: colors.textPrimary, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: text.bodySmall?.copyWith(color: colors.textSecondary, fontSize: 12),
        ),
        trailing: Icon(CupertinoIcons.chevron_forward, size: 14, color: colors.textTertiary),
        onTap: onTap,
      ),
    );
  }
}
