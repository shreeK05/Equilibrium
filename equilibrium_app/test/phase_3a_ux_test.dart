import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/core/theme/theme.dart';
import 'package:equilibrium_app/core/state/schedule_provider.dart';
import 'package:equilibrium_app/core/state/profile_provider.dart';
import 'package:equilibrium_app/core/state/timer_provider.dart';
import 'package:equilibrium_app/core/state/exam_provider.dart';
import 'package:equilibrium_app/models/task.dart';
import 'package:equilibrium_app/models/schedule.dart';
import 'package:equilibrium_app/screens/today/today_screen.dart';
import 'package:equilibrium_app/widgets/layout/app_shell.dart';
import 'package:equilibrium_app/widgets/forms/create_task_sheet.dart';

class MockScheduleProvider extends ScheduleProvider {
  MockScheduleProvider(super.api);

  @override
  Future<void> fetchDashboardData() async {
    notifyListeners();
  }
}

class MockExamProvider extends ExamProvider {
  MockExamProvider(super.api);

  @override
  Future<void> fetchAll() async {
    notifyListeners();
  }
}

Widget createTestApp({
  required Widget home,
  ScheduleProvider? scheduleProvider,
  ProfileProvider? profileProvider,
  TimerProvider? timerProvider,
  ExamProvider? examProvider,
  ApiClient? api,
}) {
  final testApi = api ?? ApiClient(baseUrl: 'http://localhost:3000/api/v1');
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: testApi),
      ChangeNotifierProvider<ScheduleProvider>.value(
        value: scheduleProvider ?? MockScheduleProvider(testApi),
      ),
      ChangeNotifierProvider<ProfileProvider>.value(
        value: profileProvider ?? ProfileProvider(testApi),
      ),
      ChangeNotifierProvider<TimerProvider>.value(
        value: timerProvider ?? TimerProvider(testApi),
      ),
      ChangeNotifierProvider<ExamProvider>.value(
        value: examProvider ?? MockExamProvider(testApi),
      ),
    ],
    child: MaterialApp(
      theme: EqTheme.lightTheme,
      darkTheme: EqTheme.darkTheme,
      home: home,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3A: 4-Destination Primary Navigation & More Hub', () {
    testWidgets('AppShell renders 4 clear destinations: Today, Plan, Tasks, More', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const AppShell(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Verify the 4 primary tabs exist
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Plan'), findsWidgets);
      expect(find.text('Tasks'), findsWidgets);
      expect(find.text('More'), findsWidgets);

      // Verify the ambiguous old label 'Locked' has been completely removed from navigation
      expect(find.text('Locked'), findsNothing);

      // Verify Quick Add FAB is accessible
      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('Tapping More tab reveals secondary destinations cleanly without data loss', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const AppShell(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Tap on the More destination (tab index 3)
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      // Check destinations inside More
      expect(find.text('Fixed Commitments'), findsOneWidget);
      expect(find.text('Exam Preparation'), findsOneWidget);

      // Scroll down to reveal subsequent sliver items
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();

      expect(find.text('Import Syllabus PDF'), findsOneWidget);
      expect(find.text('Import Academic Calendar (.ics)'), findsOneWidget);
      expect(find.text('Workload & Capacity Analytics'), findsOneWidget);
      expect(find.text('Profile & Sleep Constraints'), findsOneWidget);
    });

    testWidgets('Tapping Quick Add FAB opens clean modal with Task, Timer, Commitment, and Import options', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const AppShell(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Tap Quick Add FAB
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();

      // Modal bottom sheet should display options
      expect(find.text('Quick Add'), findsOneWidget);
      expect(find.text('Add Responsibility'), findsOneWidget);
      expect(find.text('Start Focus Session'), findsOneWidget);
      expect(find.text('Fixed Commitment'), findsOneWidget);
      expect(find.text('Import Syllabus PDF'), findsOneWidget);
      expect(find.text('Import Calendar (.ics)'), findsOneWidget);
    });
  });

  group('Phase 3A: Today Screen Visual Priority & Immediate Next Action', () {
    testWidgets('Empty/first-run state presents one obvious action: Add First Task', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);
      scheduleProvider.activeTasks = [];
      scheduleProvider.currentSchedule = null;
      scheduleProvider.commitments = [];

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Must display clean clear message and ONE obvious action
      expect(find.text('Your workload is clear.'), findsOneWidget);
      expect(find.text('Add First Task'), findsOneWidget);

      // Tapping Add First Task opens CreateTaskSheet
      await tester.tap(find.text('Add First Task'));
      await tester.pumpAndSettle();

      expect(find.byType(CreateTaskSheet), findsOneWidget);
    });

    testWidgets('Today screen renders Up Next hero card with prominent Start Focus action', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);
      final profileProvider = ProfileProvider(api);

      final now = DateTime.now();
      final upNextTask = Task(
        id: 't_next',
        userId: 'u1',
        title: 'Review Discrete Mathematics',
        estimateMinutes: 60,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 1)),
        category: 'Assignment',
        status: TaskStatus.pending,
      );

      final nextBlock = ScheduleBlock(
        id: 'b_next',
        versionId: 'v1',
        taskId: 't_next',
        startTime: now.add(const Duration(minutes: 10)),
        endTime: now.add(const Duration(minutes: 70)),
        durationMinutes: 60,
        isLocked: false,
        type: 'TASK',
      );

      scheduleProvider.currentSchedule = ScheduleVersion(
        id: 'v1',
        triggerType: 'MANUAL',
        generatedAt: now,
        capacityMinutes: 960,
        blocks: [nextBlock],
      );
      scheduleProvider.activeTasks = [upNextTask];
      scheduleProvider.commitments = [];
      scheduleProvider.constraints = {
        'sleepStart': '23:00',
        'sleepEnd': '07:00',
      };

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
        profileProvider: profileProvider,
      ));
      await tester.pumpAndSettle();

      // Check section titles and Up Next hero card
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Review Discrete Mathematics'), findsWidgets);
      expect(find.text('Start Focus'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('DAILY WORKLOAD & CAPACITY'), findsOneWidget);
      expect(find.text('PROTECTED REST'), findsOneWidget);
    });
  });

  group('Phase 3A: Task Capture Ergonomics (15-30s Quick Add)', () {
    testWidgets('CreateTaskSheet provides duration chips and deadline presets with inline validation', (tester) async {
      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: CreateTaskSheet()),
      ));
      await tester.pumpAndSettle();

      // Verify title input, duration presets, and deadline presets
      expect(find.text('Add Responsibility'), findsOneWidget);
      expect(find.text('What do you need to do?'), findsOneWidget);
      expect(find.text('15m'), findsOneWidget);
      expect(find.text('30m'), findsOneWidget);
      expect(find.text('45m'), findsOneWidget);
      expect(find.text('1h'), findsOneWidget);
      expect(find.text('Tomorrow'), findsOneWidget);
      expect(find.text('In 3 Days'), findsOneWidget);

      // Verify advanced options are collapsed by default
      expect(find.text('Additional options (Category, Notes, Pacing)'), findsOneWidget);
      expect(find.text('Notes or instructions (optional)'), findsNothing);

      // Submitting empty title triggers inline validation error
      await tester.ensureVisible(find.text('Add to Workload'));
      await tester.tap(find.text('Add to Workload'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a task title'), findsOneWidget);
    });

    testWidgets('Expanding additional options reveals Category and daily pacing target', (tester) async {
      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: CreateTaskSheet()),
      ));
      await tester.pumpAndSettle();

      // Tap on additional options accordion
      await tester.tap(find.text('Additional options (Category, Notes, Pacing)'));
      await tester.pumpAndSettle();

      // Category and Notes are now visible
      expect(find.text('Category (optional)'), findsOneWidget);
      expect(find.text('Notes or instructions (optional)'), findsOneWidget);
      expect(find.text('Pace across multiple days with a daily target'), findsOneWidget);
    });
  });

  group('Phase 3A: Narrow Phone Usability & Contrast', () {
    testWidgets('Renders cleanly on narrow phone width (320px) without overflow errors', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const AppShell(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Navigation should be intact without RenderFlex overflow
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Plan'), findsWidgets);
      expect(find.text('Tasks'), findsWidgets);
      expect(find.text('More'), findsWidgets);

      // Reset test window size
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
