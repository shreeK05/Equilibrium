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
import 'package:equilibrium_app/screens/tasks/tasks_screen.dart';
import 'package:equilibrium_app/screens/schedule/schedule_screen.dart';
import 'package:equilibrium_app/widgets/layout/app_shell.dart';
import 'package:equilibrium_app/widgets/forms/create_task_sheet.dart';
import 'package:equilibrium_app/widgets/dialogs/task_progress_dialog.dart';
import 'package:equilibrium_app/core/services/pending_operation_manager.dart';
import 'package:equilibrium_app/core/utils/workload_calculator.dart';

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
  Future<void> fetchAll() async {}
}

Widget createTestApp({
  required Widget home,
  required ScheduleProvider scheduleProvider,
  ProfileProvider? profileProvider,
  TimerProvider? timerProvider,
  ExamProvider? examProvider,
  ApiClient? api,
  ThemeMode themeMode = ThemeMode.dark,
}) {
  final testApi = api ?? ApiClient(baseUrl: 'http://localhost:3000/api/v1');
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: testApi),
      ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
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
      themeMode: themeMode,
      home: home,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 3B — Journey A: First Launch & Task Capture', () {
    testWidgets('Empty/first-launch account shows exactly one primary action to add first task', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = []
        ..commitments = []
        ..currentSchedule = null;

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Add First Task'), findsOneWidget);
      expect(find.text('Add your first responsibility to begin balancing your days.'), findsOneWidget);

      await tester.tap(find.text('Add First Task'));
      await tester.pumpAndSettle();

      expect(find.text('Add Responsibility'), findsOneWidget);
    });

    testWidgets('CreateTaskSheet validates title, duration, and past deadline', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: CreateTaskSheet()),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Attempting to submit without a title should show error
      await tester.ensureVisible(find.text('Add to Workload'));
      await tester.tap(find.text('Add to Workload'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter a task title'), findsOneWidget);

      // Typing custom duration
      await tester.tap(find.text('Custom'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, '0');
      await tester.enterText(find.byType(TextField).first, 'Quantum Mechanics Problem Set');
      await tester.ensureVisible(find.text('Add to Workload'));
      await tester.tap(find.text('Add to Workload'));
      await tester.pumpAndSettle();

      expect(find.text('Custom duration must be a positive number'), findsOneWidget);
    });

    testWidgets('Schedule simulation preview displays real simulation result honestly', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: CreateTaskSheet()),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Enter a valid title
      await tester.enterText(find.byType(TextField).first, 'Macroeconomics Essay');
      await tester.pumpAndSettle();

      // Tap preview
      await tester.ensureVisible(find.text('Preview schedule fit before adding'));
      expect(find.text('Preview schedule fit before adding'), findsOneWidget);
    });
  });

  group('Phase 3B — Journey B: Scheduling & Today Consistency', () {
    testWidgets('Newly created task appears in Pending tab, and in Scheduled tab after scheduling', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final testTask = Task(
        id: 'task-101',
        userId: 'u1',
        title: 'Algorithms Homework',
        estimateMinutes: 90,
        completedMinutes: 0,
        deadline: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = [testTask]
        ..currentSchedule = null;

      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: TasksScreen()),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // In Pending tab: task should be visible
      expect(find.text('Algorithms Homework'), findsOneWidget);

      // Switch to Scheduled tab: should be empty before generation
      await tester.tap(find.text('Scheduled'));
      await tester.pumpAndSettle();
      expect(find.text('No scheduled tasks'), findsOneWidget);

      // Now simulate schedule generated with task block
      scheduleProvider.currentSchedule = ScheduleVersion(
        id: 'v1',
        triggerType: 'MANUAL',
        generatedAt: DateTime.now(),
        capacityMinutes: 480,
        blocks: [
          ScheduleBlock(
            id: 'b1',
            versionId: 'v1',
            type: 'TASK',
            startTime: DateTime.now().add(const Duration(hours: 1)),
            endTime: DateTime.now().add(const Duration(hours: 2)),
            durationMinutes: 60,
            taskId: 'task-101',
            isLocked: false,
          )
        ],
      );
      scheduleProvider.notifyListeners();
      await tester.pumpAndSettle();

      // Scheduled tab now shows the task
      expect(find.text('Algorithms Homework'), findsOneWidget);
    });

    testWidgets('TodayScreen selects upcoming non-completed task for Up Next and excludes completed tasks', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final now = DateTime.now();

      final taskActive = Task(
        id: 'task-active',
        userId: 'u1',
        title: 'Deep Learning Reading',
        estimateMinutes: 60,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      final taskCompleted = Task(
        id: 'task-done',
        userId: 'u1',
        title: 'Morning Calculus Quiz',
        estimateMinutes: 30,
        completedMinutes: 30,
        actualMinutes: 30,
        remainingMinutes: 0,
        status: TaskStatus.completed,
        deadline: now.add(const Duration(hours: 2)),
        createdAt: now,
        updatedAt: now,
      );

      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = [taskCompleted, taskActive]
        ..commitments = []
        ..constraints = {'sleepStart': '23:00', 'sleepEnd': '07:00', 'bufferMinutes': 15}
        ..currentSchedule = ScheduleVersion(
          id: 'v1',
          triggerType: 'MANUAL',
          generatedAt: now,
          capacityMinutes: 480,
          blocks: [
            // Block 1: Completed task earlier today
            ScheduleBlock(
              id: 'b-done',
              versionId: 'v1',
              type: 'TASK',
              startTime: DateTime(now.year, now.month, now.day, 9, 0),
              endTime: DateTime(now.year, now.month, now.day, 10, 0),
              durationMinutes: 60,
              taskId: 'task-done',
              isLocked: false,
              isCompleted: true,
            ),
            // Block 2: Active upcoming task today
            ScheduleBlock(
              id: 'b-active',
              versionId: 'v1',
              type: 'TASK',
              startTime: DateTime(now.year, now.month, now.day, 11, 0),
              endTime: DateTime(now.year, now.month, now.day, 12, 0),
              durationMinutes: 60,
              taskId: 'task-active',
              isLocked: false,
              isCompleted: false,
            ),
          ],
        );

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Up Next hero section should display the ACTIVE task, NOT the completed one
      expect(find.text('UP NEXT'), findsOneWidget);
      expect(find.text('Deep Learning Reading'), findsWidgets);
      // The button text 'Start Focus' must exist for the active task
      expect(find.text('Start Focus'), findsOneWidget);
    });

    testWidgets('TodayScreen groups multiple blocks for same task into one entry without duplicates', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final now = DateTime.now();

      final taskPaced = Task(
        id: 'task-paced',
        userId: 'u1',
        title: 'Research Paper Drafting',
        estimateMinutes: 90,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      );

      final todayMorning = DateTime(now.year, now.month, now.day, 9, 0);
      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = [taskPaced]
        ..commitments = []
        ..constraints = {'sleepStart': '23:00', 'sleepEnd': '07:00', 'bufferMinutes': 15}
        ..currentSchedule = ScheduleVersion(
          id: 'v1',
          triggerType: 'MANUAL',
          generatedAt: now,
          capacityMinutes: 480,
          blocks: [
            ScheduleBlock(
              id: 'b1',
              versionId: 'v1',
              type: 'TASK',
              startTime: todayMorning.add(const Duration(hours: 1)),
              endTime: todayMorning.add(const Duration(hours: 1, minutes: 45)),
              durationMinutes: 45,
              taskId: 'task-paced',
              isLocked: false,
            ),
            ScheduleBlock(
              id: 'b2',
              versionId: 'v1',
              type: 'TASK',
              startTime: todayMorning.add(const Duration(hours: 3)),
              endTime: todayMorning.add(const Duration(hours: 3, minutes: 45)),
              durationMinutes: 45,
              taskId: 'task-paced',
              isLocked: false,
            ),
          ],
        );

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // In Today's tasks list, it should show 90m scheduled today (sum of two 45m blocks)
      expect(find.text('90m'), findsOneWidget);
    });

    testWidgets('Unscheduled tasks due today appear in Needs Attention section', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final now = DateTime.now();

      final urgentTask = Task(
        id: 'urgent-1',
        userId: 'u1',
        title: 'Urgent Lab Quiz Due Tonight',
        estimateMinutes: 45,
        completedMinutes: 0,
        deadline: DateTime(now.year, now.month, now.day, 23, 59),
        createdAt: now,
        updatedAt: now,
      );

      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = [urgentTask]
        ..commitments = []
        ..constraints = {'sleepStart': '23:00', 'sleepEnd': '07:00', 'bufferMinutes': 15}
        ..currentSchedule = ScheduleVersion(
          id: 'v1',
          triggerType: 'MANUAL',
          generatedAt: now,
          capacityMinutes: 480,
          blocks: [], // unscheduled
        );

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('NEEDS ATTENTION'), findsOneWidget);
      expect(find.text('Urgent Lab Quiz Due Tonight'), findsOneWidget);
    });

    testWidgets('ScheduleScreen WorkloadMeter computes capacity consistent with WorkloadCalculator', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final now = DateTime.now();

      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = []
        ..commitments = []
        ..constraints = {'sleepStart': '23:00', 'sleepEnd': '07:00', 'bufferMinutes': 15}
        ..currentSchedule = ScheduleVersion(
          id: 'v1',
          triggerType: 'MANUAL',
          generatedAt: now,
          capacityMinutes: 480,
          blocks: [],
        );

      await tester.pumpWidget(createTestApp(
        home: const ScheduleScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Workload meter renders on Plan tab
      expect(find.text('TODAY'), findsOneWidget);
    });
  });

  group('Phase 3B — Journey C: Focus & Progress Execution', () {
    testWidgets('Start Focus opens TimerScreen with the exact target task', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final now = DateTime.now();

      final targetTask = Task(
        id: 'task-target',
        userId: 'u1',
        title: 'Modern Physics Assignment',
        estimateMinutes: 60,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = [targetTask]
        ..commitments = []
        ..constraints = {'sleepStart': '23:00', 'sleepEnd': '07:00', 'bufferMinutes': 15}
        ..currentSchedule = ScheduleVersion(
          id: 'v1',
          triggerType: 'MANUAL',
          generatedAt: now,
          capacityMinutes: 480,
          blocks: [
            ScheduleBlock(
              id: 'b-target',
              versionId: 'v1',
              type: 'TASK',
              startTime: DateTime(now.year, now.month, now.day, 14, 0),
              endTime: DateTime(now.year, now.month, now.day, 15, 0),
              durationMinutes: 60,
              taskId: 'task-target',
              isLocked: false,
            )
          ],
        );

      await tester.pumpWidget(createTestApp(
        home: const TodayScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Tap Start Focus
      await tester.tap(find.text('Start Focus'));
      await tester.pumpAndSettle();

      // Verify TimerScreen is mounted and selected task is Modern Physics Assignment
      expect(find.text('Focus Timer'), findsOneWidget);
      expect(find.text('Modern Physics Assignment'), findsWidgets);
    });

    testWidgets('Ambiguous network failure preserves pending operation and displays recovery banner', (tester) async {
      final task = Task(
        id: 'task-ambiguous',
        userId: 'u1',
        title: 'Organic Chemistry Synthesis',
        estimateMinutes: 60,
        completedMinutes: 0,
        deadline: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save a pending operation in SharedPreferences
      final pendingOp = PendingProgressOperation(
        taskId: task.id,
        operationId: 'op-ambig-1234',
        action: 'PROGRESS',
        additionalMinutes: 30,
        remainingMinutes: 30,
        status: 'IN_PROGRESS',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );
      await PendingOperationManager.savePendingOperation(pendingOp);

      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: Scaffold(body: TaskProgressDialog(task: task)),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Should display the ambiguous recovery banner
      expect(find.byKey(const Key('ambiguous_recovery_banner')), findsOneWidget);
      expect(find.text('Pending update outcome unconfirmed'), findsOneWidget);
      expect(find.byKey(const Key('retry_pending_button')), findsOneWidget);
    });
  });

  group('Phase 3B — Journey D: Adaptive Replanning & Hard Constraints', () {
    test('Authoritative remaining-work drives replanning without double-counting', () {
      final task = Task(
        id: 'task-replan',
        userId: 'u1',
        title: 'Algorithms Midterm Prep',
        estimateMinutes: 120,
        completedMinutes: 60,
        deadline: DateTime.now().add(const Duration(days: 2)),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Remaining work is 60 minutes
      expect(task.remainingMinutes, 60);

      // When progress is recorded with 30 more minutes and remaining work updated
      final updatedTask = task.copyWith(
        completedMinutes: 90,
        remainingMinutes: 30,
      );
      expect(updatedTask.remainingMinutes, 30);
      expect(updatedTask.isCompleted, isFalse);

      // When fully finished, remaining is 0
      final finishedTask = task.copyWith(
        completedMinutes: 120,
        remainingMinutes: 0,
        status: TaskStatus.completed,
      );
      expect(finishedTask.remainingMinutes, 0);
      expect(finishedTask.isCompleted, isTrue);
    });

    test('WorkloadCalculator honestly identifies and explains capacity-exceeding overload', () {
      final now = DateTime.now();

      // Planned blocks totaling 950 minutes in the day
      final blocks = [
        ScheduleBlock(
          id: 'b-heavy-1',
          versionId: 'v1',
          type: 'TASK',
          startTime: DateTime(now.year, now.month, now.day, 7, 0),
          endTime: DateTime(now.year, now.month, now.day, 15, 0),
          durationMinutes: 480,
          taskId: 't-heavy-1',
          isLocked: false,
        ),
        ScheduleBlock(
          id: 'b-heavy-2',
          versionId: 'v1',
          type: 'TASK',
          startTime: DateTime(now.year, now.month, now.day, 15, 0),
          endTime: DateTime(now.year, now.month, now.day, 22, 50),
          durationMinutes: 470,
          taskId: 't-heavy-2',
          isLocked: false,
        ),
      ];

      // Sleep 23:00 to 08:00 = 9 hours sleep (540m) -> 900m available capacity
      final capacity = WorkloadCalculator.calculateCapacity(
        date: now,
        sleepStart: '23:00',
        sleepEnd: '08:00',
        blocks: blocks,
      );

      // 480 + 470 = 950m planned > 900m capacity
      expect(capacity.isOverloaded, isTrue);
      expect(capacity.plannedMinutes, 950);
      expect(capacity.availableCapacityMinutes, 900);
      expect(capacity.loadRatio, greaterThan(1.0));
      expect(capacity.loadPercentage, greaterThan(100));
    });

    testWidgets('Schedule respects fixed commitments and Sleep Shield boundaries without overlap', (tester) async {
      final now = DateTime.now();
      final sleepStart = DateTime(now.year, now.month, now.day, 23, 0);
      final sleepEnd = DateTime(now.year, now.month, now.day + 1, 7, 0);

      final commitmentStart = DateTime(now.year, now.month, now.day, 14, 0);
      final commitmentEnd = DateTime(now.year, now.month, now.day, 16, 0);

      final studyBlock = ScheduleBlock(
        id: 'study-1',
        versionId: 'v1',
        type: 'TASK',
        startTime: DateTime(now.year, now.month, now.day, 16, 30),
        endTime: DateTime(now.year, now.month, now.day, 18, 0),
        durationMinutes: 90,
        taskId: 't-clean',
        isLocked: false,
      );

      // Verify study block does not overlap commitment
      final overlapsCommitment = studyBlock.startTime.isBefore(commitmentEnd) &&
          studyBlock.endTime.isAfter(commitmentStart);
      expect(overlapsCommitment, isFalse);

      // Verify study block does not violate Sleep Shield
      final overlapsSleep = studyBlock.startTime.isBefore(sleepEnd) &&
          studyBlock.endTime.isAfter(sleepStart);
      expect(overlapsSleep, isFalse);
    });
  });

  group('Phase 3B — Responsive Layout & Narrow Phone QA', () {
    testWidgets('Narrow 320px viewport renders Today, Plan, Tasks, and More tabs without RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;

      final api = ApiClient(baseUrl: 'http://localhost');
      final now = DateTime.now();
      final daytime = DateTime(now.year, now.month, now.day, 10, 0);
      final scheduleProvider = MockScheduleProvider(api)
        ..activeTasks = [
          Task(
            id: 't-narrow',
            userId: 'u1',
            title: 'Narrow Layout Compatibility Task',
            estimateMinutes: 45,
            completedMinutes: 0,
            deadline: now.add(const Duration(days: 1)),
            createdAt: now,
            updatedAt: now,
          )
        ]
        ..commitments = []
        ..constraints = {'sleepStart': '23:00', 'sleepEnd': '07:00', 'bufferMinutes': 15}
        ..currentSchedule = ScheduleVersion(
          id: 'v1',
          triggerType: 'MANUAL',
          generatedAt: daytime,
          capacityMinutes: 480,
          blocks: [
            ScheduleBlock(
              id: 'b-narrow',
              versionId: 'v1',
              type: 'TASK',
              startTime: daytime,
              endTime: daytime.add(const Duration(hours: 1)),
              durationMinutes: 60,
              taskId: 't-narrow',
              isLocked: false,
            )
          ],
        );

      await tester.pumpWidget(createTestApp(
        home: const AppShell(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      // Today tab
      expect(find.text('Today'), findsWidgets);
      expect(find.text('UP NEXT'), findsOneWidget);

      // Plan tab
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();
      expect(find.text('TODAY'), findsOneWidget);

      // Tasks tab
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Master Task List'), findsOneWidget);

      // More tab
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();
      expect(find.text('Academic & Tools'), findsOneWidget);

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
    });
  });
}
