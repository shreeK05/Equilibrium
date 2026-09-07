import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/theme/theme.dart';
import '../../screens/today/today_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../../screens/tasks/tasks_screen.dart';
import '../../screens/insights/insights_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../forms/create_task_sheet.dart';
import '../forms/create_commitment_sheet.dart';
import '../../core/state/schedule_provider.dart';
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
    CommitmentsScreen(),
    TasksScreen(),
    InsightsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Today' : _currentIndex == 1 ? 'Schedule' : _currentIndex == 2 ? 'Commitments' : _currentIndex == 3 ? 'Tasks' : 'Insights',
        ),
        centerTitle: false,
        actions: [
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
              child: CircleAvatar(
                radius: 16,
                backgroundColor: colors.primary,
                child: Text('EQ', style: TextStyle(fontSize: 12, color: colors.surface, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
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
              icon: Icon(CupertinoIcons.pin),
              activeIcon: Icon(CupertinoIcons.pin_fill),
              label: 'Locked',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.list_bullet),
              activeIcon: Icon(CupertinoIcons.list_bullet_indent),
              label: 'Tasks',
            ),
            BottomNavigationBarItem(
              icon: Icon(CupertinoIcons.chart_bar),
              activeIcon: Icon(CupertinoIcons.chart_bar_fill),
              label: 'Insights',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
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
                    Text('What would you like to add?', style: TextStyle(color: colors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 24),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: colors.surfaceElevated, child: Icon(Icons.check_box_outlined, color: colors.primary)),
                      title: Text('Task', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text('A flexible assignment', style: TextStyle(color: colors.textSecondary)),
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
                    const SizedBox(height: 8),
                    ListTile(
                      leading: CircleAvatar(backgroundColor: colors.surfaceElevated, child: Icon(Icons.event, color: colors.primary)),
                      title: Text('Fixed Commitment', style: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w600)),
                      subtitle: Text('A scheduled class, lab, or meeting', style: TextStyle(color: colors.textSecondary)),
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => const CreateCommitmentSheet(), // Need to import this
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
        elevation: 4,
        child: const Icon(Icons.add),
      ).animate().scale(delay: 400.ms, duration: 300.ms, curve: Curves.easeOutBack),
    );
  }
}
