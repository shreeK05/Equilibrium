import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import '../../core/state/auth_provider.dart';
import '../../core/theme/theme.dart';
import '../../screens/today/today_screen.dart';
import '../../screens/schedule/schedule_screen.dart';
import '../forms/create_task_sheet.dart';

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
    Center(child: Text('Tasks Screen')), // Placeholder for later
    Center(child: Text('Insights Screen')), // Placeholder for later
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.eqColors;

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          _currentIndex == 0 ? 'Today' : 'Schedule',
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              context.read<AuthProvider>().logout();
            },
          ),
        ],
      ),
      body: _screens[_currentIndex],
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
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (context) => const CreateTaskSheet(),
          );
        },
        backgroundColor: colors.primary,
        foregroundColor: colors.surface,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
    );
  }
}
