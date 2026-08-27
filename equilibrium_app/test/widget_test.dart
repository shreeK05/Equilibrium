import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:equilibrium_app/core/theme/theme.dart';
import 'package:equilibrium_app/widgets/timeline/sleep_shield.dart';
import 'package:equilibrium_app/widgets/cards/task_card.dart';
import 'package:equilibrium_app/widgets/status/status_badge.dart';
import 'package:equilibrium_app/widgets/status/workload_meter.dart';
import 'package:equilibrium_app/widgets/timeline/timeline_block.dart';
import 'package:equilibrium_app/core/api/api_error_mapper.dart';
import 'package:equilibrium_app/screens/auth/login_screen.dart';
import 'package:equilibrium_app/core/state/auth_provider.dart';
import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/services/auth_repository.dart';
import 'package:equilibrium_app/models/schedule.dart';
import 'package:equilibrium_app/models/task.dart';
import 'package:equilibrium_app/models/decision_log.dart';
import 'package:equilibrium_app/widgets/timeline/timeline.dart' as equilibrium_app_timeline;
import 'package:equilibrium_app/widgets/timeline/timeline_grid.dart' as equilibrium_app_grid;
import 'package:equilibrium_app/widgets/status/change_summary.dart';

void main() {
  Widget createTestWidget(Widget child) {
    return MaterialApp(
      theme: EqTheme.lightTheme,
      home: Scaffold(body: child),
    );
  }

  Widget createAuthWidget() {
    final api = ApiClient(baseUrl: 'http://localhost:3000/api/v1');
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider(AuthRepository(api))),
      ],
      child: MaterialApp(
        theme: EqTheme.lightTheme,
        home: const LoginScreen(),
      ),
    );
  }

  testWidgets('SleepShield renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const SleepShield(
        startTime: '23:00',
        endTime: '06:00',
        durationStr: '7h 0m',
      ),
    ));

    expect(find.text('Sleep Shield'), findsOneWidget);
    expect(find.text('23:00 → 06:00'), findsOneWidget);
    expect(find.text('7h 0m'), findsOneWidget);
  });

  testWidgets('TaskCard renders status badge properly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const TaskCard(
        title: 'Math HW',
        subject: 'MATH101',
        durationStr: '2h 0m',
        deadlineStr: 'Tomorrow',
        status: EqStatus.deferred,
      ),
    ));

    expect(find.text('MATH101'), findsOneWidget);
    expect(find.text('Math HW'), findsOneWidget);
    expect(find.text('DEFERRED'), findsOneWidget);
  });

  testWidgets('WorkloadMeter rendering variations', (WidgetTester tester) async {
    // Test 1: Zero Workload
    await tester.pumpWidget(createTestWidget(
      const WorkloadMeter(plannedMinutes: 0, availableMinutes: 600)
    ));
    expect(find.text('0m planned'), findsOneWidget);

    // Test 2: Partial Workload
    await tester.pumpWidget(createTestWidget(
      const WorkloadMeter(plannedMinutes: 120, availableMinutes: 240)
    ));
    expect(find.text('2h planned'), findsOneWidget);
    expect(find.text('2h remaining'), findsOneWidget);

    // Test 3: Overcapacity Workload
    await tester.pumpWidget(createTestWidget(
      const WorkloadMeter(plannedMinutes: 300, availableMinutes: 240)
    ));
    expect(find.text('5h planned'), findsOneWidget);
    expect(find.text('0m remaining'), findsOneWidget);
  });

  testWidgets('TimelineBlock mapping variations', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const Column(
        children: [
          TimelineBlock(title: 'T1', timeRange: '10:00 → 11:00', type: BlockType.task),
          TimelineBlock(title: 'F1', timeRange: '11:00 → 12:00', type: BlockType.fixed),
          TimelineBlock(title: 'B1', timeRange: '12:00 → 13:00', type: BlockType.breakTime),
        ],
      )
    ));

    expect(find.text('T1'), findsOneWidget);
    expect(find.text('F1'), findsOneWidget);
    expect(find.text('B1'), findsOneWidget);
  });

  testWidgets('API Error Mapper translates errors', (WidgetTester tester) async {
    expect(
      ApiErrorMapper.getUserFacingMessage('VALIDATION_ERROR'),
      'Some information provided is invalid. Please check your inputs.',
    );
    expect(
      ApiErrorMapper.getUserFacingMessage('CAPACITY_EXCEEDED'),
      'Your schedule is full. Some tasks could not be placed before their deadlines.',
    );
    expect(
      ApiErrorMapper.getUserFacingMessage('UNKNOWN_MAGIC_ERROR'),
      'An unexpected communication error occurred. Please check your connection and try again.',
    );
  });

  testWidgets('LoginScreen toggles to Register', (WidgetTester tester) async {
    await tester.pumpWidget(createAuthWidget());
    
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Don\'t have an account? Create one'), findsOneWidget);
    
    await tester.tap(find.text('Don\'t have an account? Create one'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('Already have an account? Sign in'), findsOneWidget);
  });

  testWidgets('TimelineGridBackground renders correctly', (WidgetTester tester) async {
    await tester.pumpWidget(createTestWidget(
      const SingleChildScrollView(
        child: SizedBox(
          width: 500,
          height: 1000,
          child: equilibrium_app_grid.TimelineGridBackground(pixelsPerMinute: 1.0, totalMinutes: 60),
        ),
      ),
    ));

    expect(find.byType(equilibrium_app_grid.TimelineGridBackground), findsOneWidget);
  });

  testWidgets('ScheduleTimeline renders correct blocks and sleep shield', (WidgetTester tester) async {
    final now = DateTime.now();
    final schedule = ScheduleVersion(
      id: 'v1',
      horizonStart: now,
      horizonEnd: now.add(const Duration(days: 7)),
      triggerType: 'MANUAL',
      blocks: [
        ScheduleBlock(
          id: 'b1',
          versionId: 'v1',
          startTime: DateTime(now.year, now.month, now.day, 23, 0),
          endTime: DateTime(now.year, now.month, now.day, 6, 0).add(const Duration(days: 1)),
          durationMinutes: 420,
          isLocked: false,
          type: 'SLEEP',
        ),
        ScheduleBlock(
          id: 'b2',
          versionId: 'v1',
          taskId: 't1',
          startTime: DateTime(now.year, now.month, now.day, 10, 0),
          endTime: DateTime(now.year, now.month, now.day, 11, 0),
          durationMinutes: 60,
          isLocked: false,
          type: 'TASK',
        ),
      ],
    );

    final tasks = [
      Task(
        id: 't1',
        title: 'Physics HW',
        estimateMinutes: 60,
        completedMinutes: 0,
        remainingMinutes: 60,
        deadline: now.add(const Duration(days: 2)),
        cognitiveLoad: CognitiveLoad.high,
        status: TaskStatus.scheduled,
      ),
    ];

    await tester.pumpWidget(createTestWidget(
      equilibrium_app_timeline.ScheduleTimeline(schedule: schedule, tasks: tasks)
    ));

    expect(find.text('Sleep Shield', skipOffstage: false), findsOneWidget);
    expect(find.text('Physics HW', skipOffstage: false), findsOneWidget);
    expect(find.text('HIGH', skipOffstage: false), findsOneWidget); // Cognitive load
    expect(find.text('60m chunk', skipOffstage: false), findsOneWidget);
  });

  testWidgets('ChangeSummaryBanner renders metrics', (WidgetTester tester) async {
    final now = DateTime.now();
    final prev = ScheduleVersion(
      id: 'v1',
      horizonStart: now,
      horizonEnd: now.add(const Duration(days: 7)),
      triggerType: 'MANUAL',
      blocks: [
        ScheduleBlock(id: 'b1', versionId: 'v1', taskId: 't1', startTime: now, endTime: now.add(const Duration(hours: 1)), durationMinutes: 60, isLocked: false, type: 'TASK'),
      ],
      decisionLogs: [],
    );
    
    final curr = ScheduleVersion(
      id: 'v2',
      previousVersionId: 'v1',
      horizonStart: now,
      horizonEnd: now.add(const Duration(days: 7)),
      triggerType: 'DISRUPTION',
      blocks: [
        ScheduleBlock(id: 'b2', versionId: 'v2', taskId: 't1', startTime: now.add(const Duration(hours: 1)), endTime: now.add(const Duration(hours: 2)), durationMinutes: 60, isLocked: false, type: 'TASK'),
      ],
      decisionLogs: [
        DecisionLog(
          id: 'd1', versionId: 'v2', taskId: 't2', decisionType: DecisionType.deferred, priorityScore: 0.0, priorityComponents: {}, reasonCode: DecisionReason.capacityExceeded, humanReadable: 'Deferred'
        )
      ],
    );

    await tester.pumpWidget(createTestWidget(
      ChangeSummaryBanner(currentSchedule: curr, previousSchedule: prev, onDismiss: () {})
    ));

    expect(find.text('Schedule Updated'), findsOneWidget);
    expect(find.text('1 task moved'), findsOneWidget);
    expect(find.text('1 task deferred'), findsOneWidget);
  });
}
