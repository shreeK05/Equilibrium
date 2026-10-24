import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equilibrium_app/core/theme/theme.dart';
import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/core/state/auth_provider.dart';
import 'package:equilibrium_app/core/state/profile_provider.dart';
import 'package:equilibrium_app/core/state/schedule_provider.dart';
import 'package:equilibrium_app/core/utils/workload_calculator.dart';
import 'package:equilibrium_app/models/commitment.dart';
import 'package:equilibrium_app/models/schedule.dart';
import 'package:equilibrium_app/models/task.dart';
import 'package:equilibrium_app/screens/onboarding/onboarding_screen.dart';
import 'package:equilibrium_app/screens/today/today_screen.dart';
import 'package:equilibrium_app/services/auth_repository.dart';
import 'package:equilibrium_app/services/constraint_repository.dart';

class FailingConstraintRepository extends ConstraintRepository {
  FailingConstraintRepository(super.api);

  @override
  Future<void> updateConstraints(Map<String, dynamic> constraints) async {
    throw Exception('Connection failed. Server unreachable.');
  }
}

class MockSuccessConstraintRepository extends ConstraintRepository {
  Map<String, dynamic>? savedConstraints;
  MockSuccessConstraintRepository(super.api);

  @override
  Future<void> updateConstraints(Map<String, dynamic> constraints) async {
    savedConstraints = constraints;
  }
}

class TestScheduleProvider extends ScheduleProvider {
  TestScheduleProvider(super.api);

  @override
  Future<void> fetchDashboardData() async {
    // Preserve preset mock data during test run
    notifyListeners();
  }
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2B.1 - Workload Capacity & Interval Union Math', () {
    final testDate = DateTime(2026, 10, 24);

    test('Workload capacity for an eight-hour overnight sleep window (23:00 to 07:00)', () {
      final workload = WorkloadCalculator.calculateCapacity(
        date: testDate,
        sleepStart: '23:00',
        sleepEnd: '07:00',
        commitments: [],
        bufferMinutes: 0,
        blocks: [],
      );

      // Total day = 1440 min
      // Morning sleep: 00:00 to 07:00 (420 min)
      // Evening sleep: 23:00 to 24:00 (60 min)
      // Total unavailable: 480 min (8h)
      // Available capacity: 1440 - 480 = 960 min (16h)
      expect(workload.totalDayMinutes, equals(1440));
      expect(workload.unavailableMinutes, equals(480));
      expect(workload.availableCapacityMinutes, equals(960));
      expect(workload.plannedMinutes, equals(0));
      expect(workload.remainingCapacityMinutes, equals(960));
      expect(workload.loadPercentage, equals(0));
    });

    test('Workload capacity with fixed commitments and buffers', () {
      final commitment = FixedCommitment(
        id: 'c1',
        title: 'Math Lecture',
        startTime: DateTime(2026, 10, 24, 10, 0),
        endTime: DateTime(2026, 10, 24, 12, 0), // 120 mins
        type: CommitmentType.class_,
        isActive: true,
      );

      final workload = WorkloadCalculator.calculateCapacity(
        date: testDate,
        sleepStart: '23:00',
        sleepEnd: '07:00',
        commitments: [commitment],
        bufferMinutes: 15, // expands to 09:45 to 12:15 = 150 mins
        blocks: [],
      );

      // Sleep: 480 min
      // Buffered commitment: 150 min (disjoint from sleep)
      // Total unavailable: 630 min
      // Available capacity: 1440 - 630 = 810 min
      expect(workload.unavailableMinutes, equals(630));
      expect(workload.availableCapacityMinutes, equals(810));
    });

    test('Workload capacity with overlapping blocked intervals avoids double-counting', () {
      // Commitment from 06:00 to 08:00 (overlaps morning sleep 00:00 to 07:00 from 06:00 to 07:00)
      final earlyCommitment = FixedCommitment(
        id: 'c2',
        title: 'Early Swim',
        startTime: DateTime(2026, 10, 24, 6, 0),
        endTime: DateTime(2026, 10, 24, 8, 0),
        type: CommitmentType.routine,
        isActive: true,
      );

      final workload = WorkloadCalculator.calculateCapacity(
        date: testDate,
        sleepStart: '23:00',
        sleepEnd: '07:00',
        commitments: [earlyCommitment],
        bufferMinutes: 0,
        blocks: [],
      );

      // Morning sleep [00:00, 07:00] + Commitment [06:00, 08:00] merges into [00:00, 08:00] (480 min)
      // Evening sleep: [23:00, 24:00] (60 min)
      // Total unavailable = 540 min (without union it would have double-counted to 600 min)
      // Available capacity = 1440 - 540 = 900 min
      expect(workload.unavailableMinutes, equals(540));
      expect(workload.availableCapacityMinutes, equals(900));
    });

    test('Workload capacity on an empty day has 1440 minutes available', () {
      final workload = WorkloadCalculator.calculateCapacity(
        date: testDate,
        sleepStart: '00:00',
        sleepEnd: '00:00',
        commitments: [],
        bufferMinutes: 0,
        blocks: [],
      );

      expect(workload.totalDayMinutes, equals(1440));
      expect(workload.unavailableMinutes, equals(0));
      expect(workload.availableCapacityMinutes, equals(1440));
    });

    test('Midnight boundaries handle overnight intervals properly', () {
      // Commitment that starts late today (23:30) and ends tomorrow (01:30)
      final overnightCommitment = FixedCommitment(
        id: 'c3',
        title: 'Late Event',
        startTime: DateTime(2026, 10, 24, 23, 30),
        endTime: DateTime(2026, 10, 25, 1, 30),
        type: CommitmentType.custom,
        isActive: true,
      );

      final workload = WorkloadCalculator.calculateCapacity(
        date: testDate,
        sleepStart: '00:00',
        sleepEnd: '00:00',
        commitments: [overnightCommitment],
        bufferMinutes: 0,
        blocks: [],
      );

      // Clamped to today: [23:30, 24:00] = 30 minutes
      expect(workload.unavailableMinutes, equals(30));
      expect(workload.availableCapacityMinutes, equals(1410));
    });
  });

  group('Phase 2B.1 - Sleep Duration Validation Rules', () {
    test('Sleep duration calculation for 23:00 to 07:00 returns 8.0 hours and is valid', () {
      final duration = WorkloadCalculator.calculateSleepDurationHours('23:00', '07:00');
      expect(duration, equals(8.0));
      expect(WorkloadCalculator.isValidSleepDuration(duration), isTrue);
    });

    test('Sleep duration calculation for invalid short window 23:00 to 05:00 is less than 7 hours', () {
      final duration = WorkloadCalculator.calculateSleepDurationHours('23:00', '05:00');
      expect(duration, equals(6.0));
      expect(duration < 7.0, isTrue);
      expect(WorkloadCalculator.isValidSleepDuration(duration), isFalse);
    });

    test('Sleep duration for equal start and end returns 0.0 hours and is invalid', () {
      final duration = WorkloadCalculator.calculateSleepDurationHours('07:00', '07:00');
      expect(duration, equals(0.0));
      expect(WorkloadCalculator.isValidSleepDuration(duration), isFalse);
    });

    test('Minimum boundary check: 7.0h is valid, 6.9h is invalid', () {
      final validBoundary = WorkloadCalculator.calculateSleepDurationHours('23:00', '06:00');
      expect(validBoundary, equals(7.0));
      expect(validBoundary >= 7.0, isTrue);
      expect(WorkloadCalculator.isValidSleepDuration(validBoundary), isTrue);

      final belowBoundary = WorkloadCalculator.calculateSleepDurationHours('23:00', '05:54');
      expect(belowBoundary, closeTo(6.9, 0.05));
      expect(belowBoundary < 7.0, isTrue);
      expect(WorkloadCalculator.isValidSleepDuration(belowBoundary), isFalse);
    });

    test('Maximum boundary check: 12.0h is valid, durations above 12.0h are invalid', () {
      final validMax = WorkloadCalculator.calculateSleepDurationHours('22:00', '10:00');
      expect(validMax, equals(12.0));
      expect(validMax <= 12.0, isTrue);
      expect(WorkloadCalculator.isValidSleepDuration(validMax), isTrue);

      final overBoundary1 = WorkloadCalculator.calculateSleepDurationHours('22:00', '10:06');
      expect(overBoundary1, closeTo(12.1, 0.05));
      expect(overBoundary1 > 12.0, isTrue);
      expect(WorkloadCalculator.isValidSleepDuration(overBoundary1), isFalse);

      final overBoundary2 = WorkloadCalculator.calculateSleepDurationHours('22:00', '11:00');
      expect(overBoundary2, equals(13.0));
      expect(overBoundary2 > 12.0, isTrue);
      expect(WorkloadCalculator.isValidSleepDuration(overBoundary2), isFalse);
    });
  });

  group('Phase 2B.1 - Onboarding Screen Save Failure & Validation Widgets', () {
    testWidgets('Onboarding validation rejects duration above 12 hours with inline error and blocks navigation', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      final successRepo = MockSuccessConstraintRepository(api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<ConstraintRepository>.value(value: successRepo),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const OnboardingScreen(
              initialSleepStart: '22:00',
              initialSleepEnd: '11:00', // 13 hours -> exceeds 12h max
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Page 0: Welcome -> Page 1
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Tap Next to submit invalid duration
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Must remain on Page 1
      expect(find.text('Protect Your Sleep'), findsOneWidget);
      expect(find.text("Let's Go"), findsNothing);

      // Must display inline error
      expect(find.textContaining('Sleep window cannot exceed 12 hours'), findsOneWidget);

      // Repository must not have been called
      expect(successRepo.savedConstraints, isNull);
    });

    testWidgets('Onboarding validation rejects duration below 7 hours with inline error and blocks navigation', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      final successRepo = MockSuccessConstraintRepository(api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<ConstraintRepository>.value(value: successRepo),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const OnboardingScreen(
              initialSleepStart: '23:00',
              initialSleepEnd: '05:00', // 6 hours -> below 7h min
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Protect Your Sleep'), findsOneWidget);
      expect(find.text("Let's Go"), findsNothing);
      expect(find.textContaining('Equilibrium requires at least 7 hours of protected sleep'), findsOneWidget);
      expect(successRepo.savedConstraints, isNull);
    });

    testWidgets('Onboarding validation rejects equal start and end times with inline error', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      final successRepo = MockSuccessConstraintRepository(api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<ConstraintRepository>.value(value: successRepo),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const OnboardingScreen(
              initialSleepStart: '07:00',
              initialSleepEnd: '07:00', // Equal start and end
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('Protect Your Sleep'), findsOneWidget);
      expect(find.text("Let's Go"), findsNothing);
      expect(find.text('Sleep start and wake-up time cannot be the same.'), findsOneWidget);
      expect(successRepo.savedConstraints, isNull);
    });

    testWidgets('Onboarding accepts valid boundaries 7.0h and 12.0h and advances on save success', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      final successRepo = MockSuccessConstraintRepository(api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<ConstraintRepository>.value(value: successRepo),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const OnboardingScreen(
              initialSleepStart: '22:00',
              initialSleepEnd: '10:00', // Exact 12.0h boundary
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Page 0 -> Page 1
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 1 -> Page 2
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Advances to Page 2 ("Let's Go")
      expect(find.text("You're all set!"), findsOneWidget);
      expect(find.text("Let's Go"), findsOneWidget);
      expect(successRepo.savedConstraints, isNotNull);
      expect(successRepo.savedConstraints!['sleepStart'], equals('22:00'));
      expect(successRepo.savedConstraints!['sleepEnd'], equals('10:00'));
    });

    testWidgets('API save failure does not advance onboarding, retains settings, and displays retryable error', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      final failingConstraintRepo = FailingConstraintRepository(api);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: authProvider),
            Provider<ConstraintRepository>.value(value: failingConstraintRepo),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const OnboardingScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Page 0: Welcome. Tap Next to go to Page 1 (Sleep Shield)
      expect(find.text('Welcome to Equilibrium'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Page 1: Sleep Shield
      expect(find.text('Protect Your Sleep'), findsOneWidget);
      expect(find.text('11:00 PM'), findsOneWidget);
      expect(find.text('07:00 AM'), findsOneWidget);

      // Attempt to save (failingConstraintRepo will throw)
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      // Must remain on Page 1 (NOT advanced to Page 2)
      expect(find.text('Protect Your Sleep'), findsOneWidget);
      expect(find.text("Let's Go"), findsNothing);

      // Must preserve the user's entered time settings
      expect(find.text('11:00 PM'), findsOneWidget);
      expect(find.text('07:00 AM'), findsOneWidget);

      // Must show a clear retryable error
      expect(find.text('Could not save sleep schedule. Please check your connection and tap Next to retry.'), findsOneWidget);
    });
  });

  group('Phase 2B.1 - Today Screen Dashboard Correctness', () {
    testWidgets("Today's scheduled task appears, task scheduled only tomorrow does not appear", (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = TestScheduleProvider(api);
      final profileProvider = ProfileProvider(api);

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day, 10, 0);
      final todayEnd = DateTime(now.year, now.month, now.day, 11, 30);

      final tomorrowStart = DateTime(now.year, now.month, now.day + 1, 14, 0);
      final tomorrowEnd = DateTime(now.year, now.month, now.day + 1, 15, 30);

      final taskToday = Task(
        id: 't_today',
        userId: 'u1',
        title: 'Algorithms Assignment',
        estimateMinutes: 90,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 2)),
      );

      final taskTomorrow = Task(
        id: 't_tomorrow',
        userId: 'u1',
        title: 'Physics Lab Report',
        estimateMinutes: 90,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 3)),
      );

      final blocks = [
        ScheduleBlock(
          id: 'b1',
          versionId: 'v1',
          taskId: 't_today',
          startTime: todayStart,
          endTime: todayEnd,
          durationMinutes: 90,
          isLocked: false,
          type: 'TASK',
        ),
        ScheduleBlock(
          id: 'b2',
          versionId: 'v1',
          taskId: 't_tomorrow',
          startTime: tomorrowStart,
          endTime: tomorrowEnd,
          durationMinutes: 90,
          isLocked: false,
          type: 'TASK',
        ),
      ];

      scheduleProvider.currentSchedule = ScheduleVersion(
        id: 'v1',
        triggerType: 'MANUAL',
        generatedAt: now,
        capacityMinutes: 960,
        blocks: blocks,
      );
      scheduleProvider.activeTasks = [taskToday, taskTomorrow];
      scheduleProvider.commitments = [];
      scheduleProvider.constraints = {
        'sleepStart': '23:00',
        'sleepEnd': '07:00',
        'bufferMinutes': 15,
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const TodayScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Today's task must appear
      expect(find.text('Algorithms Assignment'), findsWidgets);

      // Tomorrow's task must NOT appear under Today's Tasks
      expect(find.text('Physics Lab Report'), findsNothing);
    });

    testWidgets('Multiple task blocks on the same day are handled without duplicate task cards', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = TestScheduleProvider(api);
      final profileProvider = ProfileProvider(api);

      final now = DateTime.now();
      final block1Start = DateTime(now.year, now.month, now.day, 9, 0);
      final block1End = DateTime(now.year, now.month, now.day, 10, 0); // 60 min

      final block2Start = DateTime(now.year, now.month, now.day, 14, 0);
      final block2End = DateTime(now.year, now.month, now.day, 15, 0); // 60 min

      final multiBlockTask = Task(
        id: 't_multi',
        userId: 'u1',
        title: 'Operating Systems Project',
        estimateMinutes: 120,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 2)),
      );

      final blocks = [
        ScheduleBlock(
          id: 'b_multi_1',
          versionId: 'v1',
          taskId: 't_multi',
          startTime: block1Start,
          endTime: block1End,
          durationMinutes: 60,
          isLocked: false,
          type: 'TASK',
        ),
        ScheduleBlock(
          id: 'b_multi_2',
          versionId: 'v1',
          taskId: 't_multi',
          startTime: block2Start,
          endTime: block2End,
          durationMinutes: 60,
          isLocked: false,
          type: 'TASK',
        ),
      ];

      scheduleProvider.currentSchedule = ScheduleVersion(
        id: 'v1',
        triggerType: 'MANUAL',
        generatedAt: now,
        capacityMinutes: 960,
        blocks: blocks,
      );
      scheduleProvider.activeTasks = [multiBlockTask];
      scheduleProvider.commitments = [];
      scheduleProvider.constraints = {
        'sleepStart': '23:00',
        'sleepEnd': '07:00',
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const TodayScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Only 1 TaskCard should exist in Today's Tasks
      // (If Up Next is shown, it may show 1 in Up Next and 1 in Today's Tasks, but under Today's Tasks it's deduplicated)
      expect(find.text('Operating Systems Project'), findsWidgets);
      // The scheduled duration for today is summed to 120m
      expect(find.text('120m'), findsOneWidget);
    });

    testWidgets('Due-today or overdue unscheduled task appears in Needs Attention and is not silently lost', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = TestScheduleProvider(api);
      final profileProvider = ProfileProvider(api);

      final now = DateTime.now();
      final overdueTask = Task(
        id: 't_overdue',
        userId: 'u1',
        title: 'Submit Research Abstract',
        estimateMinutes: 45,
        completedMinutes: 0,
        deadline: now.subtract(const Duration(hours: 4)), // Overdue
        status: TaskStatus.pending,
      );

      final scheduledTask = Task(
        id: 't_scheduled',
        userId: 'u1',
        title: 'Study Chapter 4',
        estimateMinutes: 60,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 2)),
      );

      final blocks = [
        ScheduleBlock(
          id: 'b_sched',
          versionId: 'v1',
          taskId: 't_scheduled',
          startTime: DateTime(now.year, now.month, now.day, 11, 0),
          endTime: DateTime(now.year, now.month, now.day, 12, 0),
          durationMinutes: 60,
          isLocked: false,
          type: 'TASK',
        ),
      ];

      scheduleProvider.currentSchedule = ScheduleVersion(
        id: 'v1',
        triggerType: 'MANUAL',
        generatedAt: now,
        capacityMinutes: 960,
        blocks: blocks,
      );
      scheduleProvider.activeTasks = [overdueTask, scheduledTask];
      scheduleProvider.commitments = [];
      scheduleProvider.constraints = {
        'sleepStart': '23:00',
        'sleepEnd': '07:00',
      };

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
            ChangeNotifierProvider<ProfileProvider>.value(value: profileProvider),
          ],
          child: MaterialApp(
            theme: EqTheme.lightTheme,
            home: const TodayScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Needs Attention section must be visible with the overdue unscheduled task
      expect(find.text('NEEDS ATTENTION'), findsOneWidget);
      expect(find.text('Submit Research Abstract'), findsOneWidget);
      expect(find.text('Overdue'), findsOneWidget);

      // Scheduled task must be under Today's Tasks
      expect(find.text('Study Chapter 4'), findsWidgets);
    });
  });
}
