import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../screens/today/today_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../screens/tasks/tasks_screen.dart';
import '../../screens/exams/exams_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/timer/timer_screen.dart';
import '../forms/create_task_sheet.dart';
import '../forms/create_commitment_sheet.dart';
import '../../core/state/schedule_provider.dart';
import '../../core/state/timer_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../screens/commitments/commitments_screen.dart';

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
    ExamsScreen(),
    CommitmentsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    final tabTitles = ['Today', 'Schedule', 'Tasks', 'Exams', 'Commitments'];

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(tabTitles[_currentIndex]),
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
              child: Consumer(
                builder: (context, _, child) {
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: colors.primary,
                    child: Text(
                      'EQ',
                      style: TextStyle(fontSize: 12, color: colors.surface, fontWeight: FontWeight.bold),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: _screens[_currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: colors.surfaceElevated, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          selectedFontSize: 10,
          unselectedFontSize: 10,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.sun_max),
              activeIcon: Icon(CupertinoIcons.sun_max_fill),
              label: 'Today',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.calendar),
              activeIcon: Icon(CupertinoIcons.calendar_today),
              label: 'Schedule',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.list_bullet),
              activeIcon: Icon(CupertinoIcons.list_bullet_indent),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.book),
              activeIcon: Icon(CupertinoIcons.book_fill),
              label: 'Exams',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.pin),
              activeIcon: Icon(CupertinoIcons.pin_fill),
              label: 'Locked',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAdd(context),
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
        elevation: 4,
        child: const Icon(Icons.add),
      ).animate().scale(delay: 400.ms, duration: 300.ms, curve: Curves.easeOutBack),
    );
  }

  void _showQuickAdd(BuildContext context) {
    final colors = context.eqColors;
    showModalBottomSheet(
      context: context,
      backgroundColor: colors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('What would you like to add?',
                style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),
              ListTile(
                leading: CircleAvatar(backgroundColor: colors.surfaceElevated, child: Icon(Icons.check_box_outlined, color: colors.primary)),
                title: Text('Task', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('A flexible assignment or study task', style: TextStyle(color: colors.textSecondary)),
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
              const SizedBox(height: 4),
              ListTile(
                leading: CircleAvatar(backgroundColor: colors.surfaceElevated, child: Icon(Icons.timer_outlined, color: colors.primary)),
                title: Text('Start Timer', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('Begin a focused study session', style: TextStyle(color: colors.textSecondary)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
                },
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: CircleAvatar(backgroundColor: colors.surfaceElevated, child: Icon(Icons.event, color: colors.primary)),
                title: Text('Fixed Commitment', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                subtitle: Text('A scheduled class, lab, routine, or meeting', style: TextStyle(color: colors.textSecondary)),
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
            ],
          ),
        ),
      ),
    );
  }
}
