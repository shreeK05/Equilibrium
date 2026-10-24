import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equilibrium_app/core/theme/theme.dart';
import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/core/state/schedule_provider.dart';
import 'package:equilibrium_app/models/task.dart';
import 'package:equilibrium_app/widgets/dialogs/task_progress_dialog.dart';
import 'package:equilibrium_app/core/services/pending_operation_manager.dart';
import 'package:equilibrium_app/core/utils/uuid_generator.dart';

class MockScheduleProvider extends ScheduleProvider {
  bool completeTaskCalled = false;
  String? lastCompletedTaskId;
  int? lastActualMinutes;
  String? lastCompletedOperationId;

  bool recordProgressCalled = false;
  String? lastProgressTaskId;
  int? lastProgressCompletedMinutes;
  int? lastProgressAdditionalMinutes;
  int? lastProgressActualMinutes;
  int? lastProgressRemainingMinutes;
  int? lastProgressNewEstimateMinutes;
  String? lastProgressStatus;
  String? lastProgressOperationId;
  final List<String> recordedOperationIds = [];

  bool rescheduleCalled = false;
  ReplanSummary? mockReplanSummary;
  bool shouldFail = false;
  String? failErrorMessage;
  Map<String, dynamic>? operationStatusResult;
  bool operationStatusCalled = false;

  MockScheduleProvider(super.api);

  @override
  Future<Map<String, dynamic>?> getTaskOperation(String taskId, String operationId) async {
    operationStatusCalled = true;
    return operationStatusResult;
  }

  @override
  Future<void> fetchDashboardData() async {
    notifyListeners();
  }

  @override
  Future<bool> completeTask(String id, [int? actualMinutes, String? operationId]) async {
    completeTaskCalled = true;
    lastCompletedTaskId = id;
    lastActualMinutes = actualMinutes;
    lastCompletedOperationId = operationId;
    if (shouldFail) {
      if (lastApiException != null) {
        isLastFailureAmbiguous = lastApiException!.isAmbiguous;
        errorMessage = failErrorMessage ?? lastApiException!.message;
      } else {
        isLastFailureAmbiguous = false;
        errorMessage = failErrorMessage ?? 'Server error on completion';
      }
      notifyListeners();
      return false;
    }
    final idx = activeTasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final old = activeTasks[idx];
      final recordedActual = actualMinutes ?? (old.actualMinutes > 0 ? old.actualMinutes : old.estimateMinutes);
      activeTasks[idx] = Task(
        id: old.id,
        userId: old.userId,
        title: old.title,
        description: old.description,
        category: old.category,
        estimateMinutes: old.estimateMinutes,
        deadline: old.deadline,
        deadlineType: old.deadlineType,
        status: TaskStatus.completed,
        completedMinutes: recordedActual,
        actualMinutes: recordedActual,
        remainingMinutes: 0,
        scheduledMinutes: old.scheduledMinutes,
        createdAt: old.createdAt,
      );
    }
    notifyListeners();
    return true;
  }

  @override
  Future<bool> recordTaskProgress(
    String id, {
    int? completedMinutes,
    int? additionalMinutes,
    int? actualMinutes,
    int? remainingMinutes,
    int? newEstimateMinutes,
    String? status,
    String? operationId,
  }) async {
    recordProgressCalled = true;
    lastProgressTaskId = id;
    lastProgressCompletedMinutes = completedMinutes;
    lastProgressAdditionalMinutes = additionalMinutes;
    lastProgressActualMinutes = actualMinutes;
    lastProgressRemainingMinutes = remainingMinutes;
    lastProgressNewEstimateMinutes = newEstimateMinutes;
    lastProgressStatus = status;
    lastProgressOperationId = operationId;
    if (operationId != null) recordedOperationIds.add(operationId);
    if (shouldFail) {
      if (lastApiException != null) {
        isLastFailureAmbiguous = lastApiException!.isAmbiguous;
        errorMessage = failErrorMessage ?? lastApiException!.message;
      } else {
        isLastFailureAmbiguous = false;
        errorMessage = failErrorMessage ?? 'Server error on progress';
      }
      notifyListeners();
      return false;
    }
    final idx = activeTasks.indexWhere((t) => t.id == id);
    if (idx != -1) {
      final old = activeTasks[idx];
      final newActual = actualMinutes ?? (completedMinutes ?? (old.actualMinutes + (additionalMinutes ?? 0)));
      final newRemaining = remainingMinutes ?? (status == 'COMPLETED' ? 0 : (old.remainingMinutes - (additionalMinutes ?? 0)).clamp(0, 100000));
      final newEst = newEstimateMinutes ?? old.estimateMinutes;
      final newStatus = status == 'COMPLETED'
          ? TaskStatus.completed
          : (status == 'IN_PROGRESS'
              ? TaskStatus.inProgress
              : (newRemaining == 0 ? TaskStatus.completed : TaskStatus.inProgress));
      activeTasks[idx] = Task(
        id: old.id,
        userId: old.userId,
        title: old.title,
        description: old.description,
        category: old.category,
        estimateMinutes: newEst,
        deadline: old.deadline,
        deadlineType: old.deadlineType,
        status: newStatus,
        completedMinutes: newActual,
        actualMinutes: newActual,
        remainingMinutes: newRemaining,
        scheduledMinutes: old.scheduledMinutes,
        createdAt: old.createdAt,
      );
    }
    notifyListeners();
    return true;
  }

  @override
  Future<ReplanSummary?> reschedule() async {
    rescheduleCalled = true;
    if (shouldFail) {
      errorMessage = failErrorMessage ?? 'Server error on reschedule';
      notifyListeners();
      return null;
    }
    return mockReplanSummary ?? const ReplanSummary(
      scheduledTaskCount: 2,
      totalScheduledMinutes: 120,
      deferredTaskCount: 0,
      deferredTaskTitles: [],
      hasDeferred: false,
      userMessage: 'Schedule updated: 120 min planned across 2 tasks.',
    );
  }
}

Widget createTestApp({
  required Widget child,
  required MockScheduleProvider provider,
}) {
  return ChangeNotifierProvider<ScheduleProvider>.value(
    value: provider,
    child: MaterialApp(
      theme: EqTheme.darkTheme,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 2B.2 - Task Progress Dialog & Execution Flow', () {
    late MockScheduleProvider provider;
    late Task testTask;

    setUp(() {
      provider = MockScheduleProvider(ApiClient());
      testTask = Task(
        id: 'task-101',
        userId: 'user-1',
        title: 'Algorithms Homework',
        estimateMinutes: 90,
        deadline: DateTime.now().add(const Duration(days: 2)),
        status: TaskStatus.inProgress,
        completedMinutes: 30,
        scheduledMinutes: 60,
      );
      provider.activeTasks = [testTask];
    });

    testWidgets('Finished option records exact actual minutes and sets completed status', (tester) async {
      TaskProgressResult? dialogResult;

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await TaskProgressDialog.show(
                context,
                task: testTask,
                scheduledBlockMinutes: 45,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check header and options
      expect(find.text('TASK PROGRESS'), findsOneWidget);
      expect(find.text('Algorithms Homework'), findsOneWidget);
      expect(find.text('Finished'), findsOneWidget);
      expect(find.text('Made Progress'), findsOneWidget);
      expect(find.text('Need More Time'), findsOneWidget);
      expect(find.text('Not Now'), findsOneWidget);

      // Select 'Finished'
      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      expect(find.text('Mark as Finished'), findsOneWidget);
      expect(find.text('Confirm Task Finished'), findsOneWidget);

      // Modify actual minutes to 50
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, '50');
      await tester.pumpAndSettle();

      // Confirm finished
      await tester.tap(find.text('Confirm Task Finished'));
      await tester.pumpAndSettle();

      expect(provider.completeTaskCalled, isTrue);
      expect(provider.lastCompletedTaskId, equals('task-101'));
      expect(provider.lastActualMinutes, equals(50));
      expect(dialogResult?.action, equals(TaskProgressAction.finished));
      expect(dialogResult?.actualMinutes, equals(50));
    });

    testWidgets('Made Progress records incremental work and keeps unfinished workload active', (tester) async {
      TaskProgressResult? dialogResult;

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await TaskProgressDialog.show(
                context,
                task: testTask,
                scheduledBlockMinutes: 30,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Select 'Made Progress'
      await tester.tap(find.text('Made Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Record Session Progress'), findsOneWidget);
      expect(find.text('Save Progress'), findsOneWidget);

      // Enter 25 minutes
      final textField = find.byType(TextField);
      await tester.enterText(textField, '25');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save Progress'));
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(provider.recordProgressCalled, isTrue);
      expect(provider.lastProgressTaskId, equals('task-101'));
      expect(provider.lastProgressAdditionalMinutes, equals(25));
      expect(provider.lastProgressStatus, equals('IN_PROGRESS'));
      expect(dialogResult?.action, equals(TaskProgressAction.madeProgress));
      expect(dialogResult?.additionalMinutes, equals(25));

      // Task remains active in provider with 30 + 25 = 55 completed of 90
      final updated = provider.activeTasks.firstWhere((t) => t.id == 'task-101');
      expect(updated.status, equals(TaskStatus.inProgress));
      expect(updated.completedMinutes, equals(55));
    });

    testWidgets('Need More Time increases estimate and triggers adaptive rescheduling', (tester) async {
      TaskProgressResult? dialogResult;

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await TaskProgressDialog.show(
                context,
                task: testTask,
                scheduledBlockMinutes: 30,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Select 'Need More Time'
      await tester.tap(find.text('Need More Time'));
      await tester.pumpAndSettle();

      expect(find.text('Save & Re-plan My Remaining Day'), findsOneWidget);

      // Enter session worked = 10, extra needed = 40
      final textFields = find.byType(TextField);
      expect(textFields, findsNWidgets(2));
      await tester.enterText(textFields.at(0), '10');
      await tester.enterText(textFields.at(1), '40');
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Save & Re-plan My Remaining Day'));
      await tester.tap(find.text('Save & Re-plan My Remaining Day'));
      await tester.pumpAndSettle();

      expect(provider.recordProgressCalled, isTrue);
      expect(provider.lastProgressTaskId, equals('task-101'));
      expect(provider.lastProgressAdditionalMinutes, equals(10));
      expect(provider.lastProgressRemainingMinutes, equals(40));
      // New estimate = currentCompleted (30) + sessionWorked (10) + extraNeeded (40) = 80
      expect(provider.lastProgressNewEstimateMinutes, equals(80));
      expect(provider.rescheduleCalled, isTrue);
      expect(dialogResult?.action, equals(TaskProgressAction.needMoreTime));
      expect(dialogResult?.remainingMinutes, equals(40));
      expect(dialogResult?.replanSummary, isNotNull);
    });

    testWidgets('Not Now dismisses dialog with null and makes no changes', (tester) async {
      TaskProgressResult? dialogResult;

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              dialogResult = await TaskProgressDialog.show(
                context,
                task: testTask,
                scheduledBlockMinutes: 30,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Tap 'Not Now'
      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(dialogResult, isNull);
      expect(provider.completeTaskCalled, isFalse);
      expect(provider.recordProgressCalled, isFalse);
      expect(provider.rescheduleCalled, isFalse);
    });

    testWidgets('Validates input and prevents submission with invalid numbers', (tester) async {
      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await TaskProgressDialog.show(
                context,
                task: testTask,
                scheduledBlockMinutes: 30,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Test invalid progress minutes (0 or empty)
      await tester.tap(find.text('Made Progress'));
      await tester.pumpAndSettle();

      final textField = find.byType(TextField);
      await tester.enterText(textField, '0');
      await tester.ensureVisible(find.text('Save Progress'));
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter positive minutes worked (>= 1)'), findsOneWidget);
      expect(provider.recordProgressCalled, isFalse);
    });

    testWidgets('Displays error message and remains open upon API save failure', (tester) async {
      provider.shouldFail = true;
      provider.failErrorMessage = 'Failed to persist task progress: server unavailable';

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await TaskProgressDialog.show(
                context,
                task: testTask,
                scheduledBlockMinutes: 30,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Finished'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Confirm Task Finished'));
      await tester.pumpAndSettle();

      // Error message shown and dialog still visible
      expect(find.text('Failed to persist task progress: server unavailable'), findsOneWidget);
      expect(find.text('Confirm Task Finished'), findsOneWidget);
    });

    testWidgets('Overrun task (60m estimate, 90m actual, 30m remaining) retains inProgress status and separate dimensions', (tester) async {
      final overrunTask = Task(
        id: 'task-overrun',
        userId: 'user-1',
        title: 'Overrun Analysis Lab',
        estimateMinutes: 60,
        completedMinutes: 90,
        actualMinutes: 90,
        remainingMinutes: 30,
        deadline: DateTime.now().add(const Duration(days: 2)),
        status: TaskStatus.inProgress,
        scheduledMinutes: 30,
      );
      provider.activeTasks = [overrunTask];

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              await TaskProgressDialog.show(
                context,
                task: overrunTask,
                scheduledBlockMinutes: 30,
              );
            },
            child: const Text('Open Dialog'),
          ),
        ),
      ));

      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Check header shows separate actual effort and remaining work
      expect(find.text('90m effort logged • 30m remaining'), findsOneWidget);

      // Verify task in provider preserves status inProgress and remainingMinutes 30
      expect(overrunTask.status, equals(TaskStatus.inProgress));
      expect(overrunTask.actualMinutes, equals(90));
      expect(overrunTask.remainingMinutes, equals(30));
    });

    test('Task model separates estimateMinutes, actualMinutes, and remainingMinutes on overrun and early completion', () {
      // Overrun scenario
      final overrun = Task(
        id: 't-overrun',
        userId: 'u1',
        title: 'Overrun Lab',
        estimateMinutes: 60,
        completedMinutes: 90,
        actualMinutes: 90,
        remainingMinutes: 30,
        deadline: DateTime.now().add(const Duration(days: 1)),
        status: TaskStatus.inProgress,
      );
      expect(overrun.estimateMinutes, equals(60));
      expect(overrun.actualMinutes, equals(90));
      expect(overrun.remainingMinutes, equals(30));
      expect(overrun.status, equals(TaskStatus.inProgress));
      expect(overrun.isCompleted, isFalse);

      // Early completion scenario
      final earlyFinished = Task(
        id: 't-early',
        userId: 'u1',
        title: 'Fast Quiz',
        estimateMinutes: 60,
        completedMinutes: 35,
        actualMinutes: 35,
        remainingMinutes: 0,
        deadline: DateTime.now().add(const Duration(days: 1)),
        status: TaskStatus.completed,
      );
      expect(earlyFinished.estimateMinutes, equals(60));
      expect(earlyFinished.actualMinutes, equals(35));
      expect(earlyFinished.remainingMinutes, equals(0));
      expect(earlyFinished.status, equals(TaskStatus.completed));
      expect(earlyFinished.isCompleted, isTrue);
    });
  });

  group('Phase 2B.2 - Adaptive Re-planning Summary Semantics', () {
    test('ReplanSummary truthfully reports deferred tasks when workload cannot fit', () {
      const summaryWithDeferred = ReplanSummary(
        scheduledTaskCount: 1,
        totalScheduledMinutes: 60,
        deferredTaskCount: 2,
        deferredTaskTitles: ['Compiler Project', 'Discrete Math Homework'],
        hasDeferred: true,
        userMessage: 'Re-planned: 60 min scheduled. 2 task(s) deferred (Compiler Project, Discrete Math Homework) due to capacity.',
      );

      expect(summaryWithDeferred.hasDeferred, isTrue);
      expect(summaryWithDeferred.deferredTaskCount, equals(2));
      expect(summaryWithDeferred.deferredTaskTitles, contains('Compiler Project'));
      expect(summaryWithDeferred.userMessage, contains('2 task(s) deferred'));
      // Never falsely claims all tasks fit
      expect(summaryWithDeferred.userMessage, isNot(contains('all tasks fit')));
    });

    test('ReplanSummary reports complete fit when no tasks are deferred', () {
      const fitSummary = ReplanSummary(
        scheduledTaskCount: 3,
        totalScheduledMinutes: 150,
        deferredTaskCount: 0,
        deferredTaskTitles: [],
        hasDeferred: false,
        userMessage: 'Schedule updated: 150 min planned across 3 tasks.',
      );

      expect(fitSummary.hasDeferred, isFalse);
      expect(fitSummary.deferredTaskCount, equals(0));
      expect(fitSummary.userMessage, equals('Schedule updated: 150 min planned across 3 tasks.'));
    });
  });

  group('Phase 2B.2.2 - Persistent Idempotency & Retry Safety', () {
    test('generateUuidV4 produces valid RFC 4122 version 4 UUIDs', () {
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      final ids = <String>{};

      for (int i = 0; i < 500; i++) {
        final id = generateUuidV4();
        expect(uuidRegex.hasMatch(id), isTrue, reason: 'UUID $id does not match RFC 4122 v4 format');
        ids.add(id);
      }

      expect(ids.length, equals(500), reason: 'All 500 generated UUIDs must be distinct');
    });

    testWidgets('Made Progress generates operationId and forwards it to ScheduleProvider', (tester) async {
      final task = Task(
        id: 't-idem-1',
        userId: 'u1',
        title: 'Idempotent Task',
        estimateMinutes: 60,
        completedMinutes: 10,
        actualMinutes: 10,
        remainingMinutes: 50,
        deadline: DateTime.now().add(const Duration(days: 2)),
      );

      final provider = MockScheduleProvider(ApiClient());
      provider.activeTasks = [task];

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: TaskProgressDialog(task: task, scheduledBlockMinutes: 30),
      ));
      await tester.pumpAndSettle();

      // Tap Made Progress
      await tester.tap(find.text('Made Progress'));
      await tester.pumpAndSettle();

      // Tap Save Progress
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(provider.recordProgressCalled, isTrue);
      expect(provider.lastProgressOperationId, isNotNull);
      final uuidRegex = RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
      expect(uuidRegex.hasMatch(provider.lastProgressOperationId!), isTrue);
    });

    testWidgets('Retrying submission after failure reuses the exact same operationId and preserves form inputs', (tester) async {
      final task = Task(
        id: 't-idem-retry',
        userId: 'u1',
        title: 'Retry Safe Task',
        estimateMinutes: 60,
        completedMinutes: 0,
        actualMinutes: 0,
        remainingMinutes: 60,
        deadline: DateTime.now().add(const Duration(days: 2)),
      );

      final provider = MockScheduleProvider(ApiClient());
      provider.activeTasks = [task];
      provider.shouldFail = true;
      provider.failErrorMessage = 'Simulated network timeout';

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: TaskProgressDialog(task: task, scheduledBlockMinutes: 30),
      ));
      await tester.pumpAndSettle();

      // Select Made Progress
      await tester.tap(find.text('Made Progress'));
      await tester.pumpAndSettle();

      // First attempt fails
      await tester.ensureVisible(find.text('Save Progress'));
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(find.text('Simulated network timeout'), findsOneWidget);
      expect(provider.recordedOperationIds.length, equals(1));
      final firstOpId = provider.recordedOperationIds[0];

      // Form input must NOT be lost
      expect(find.text('30'), findsOneWidget);

      // Provider recovers
      provider.shouldFail = false;

      // Tap Save Progress again without touching inputs (retry)
      await tester.ensureVisible(find.text('Save Progress'));
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(provider.recordedOperationIds.length, equals(2));
      final secondOpId = provider.recordedOperationIds[1];

      // Crucial: The exact same operationId was reused across the retry!
      expect(secondOpId, equals(firstOpId));
    });

    testWidgets('Modifying an input field invalidates operationId so next submit generates a fresh one', (tester) async {
      final task = Task(
        id: 't-idem-mod',
        userId: 'u1',
        title: 'Modified Input Task',
        estimateMinutes: 60,
        completedMinutes: 0,
        actualMinutes: 0,
        remainingMinutes: 60,
        deadline: DateTime.now().add(const Duration(days: 2)),
      );

      final provider = MockScheduleProvider(ApiClient());
      provider.activeTasks = [task];
      provider.shouldFail = true;

      await tester.pumpWidget(createTestApp(
        provider: provider,
        child: TaskProgressDialog(task: task, scheduledBlockMinutes: 30),
      ));
      await tester.pumpAndSettle();

      // Select Made Progress
      await tester.tap(find.text('Made Progress'));
      await tester.pumpAndSettle();

      // First attempt (fails)
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(provider.recordedOperationIds.length, equals(1));
      final firstOpId = provider.recordedOperationIds[0];

      // User changes the input to 45
      await tester.enterText(find.byType(TextField), '45');
      await tester.pumpAndSettle();

      provider.shouldFail = false;

      // Submit with modified payload
      await tester.tap(find.text('Save Progress'));
      await tester.pumpAndSettle();

      expect(provider.recordedOperationIds.length, equals(2));
      final secondOpId = provider.recordedOperationIds[1];

      // Fresh operation ID because payload was modified!
      expect(secondOpId, isNot(equals(firstOpId)));
    });

    group('Phase 2B.2.3 - Ambiguous Retry Recovery & Persistence', () {
      testWidgets('Ambiguous network failure locks inputs, shows recovery banner, and preserves operationId in SharedPreferences', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final task = Task(
          id: 'ambiguous-task-1',
          userId: 'user-1',
          title: 'Network Drop Task',
          estimateMinutes: 60,
          completedMinutes: 0,
          actualMinutes: 0,
          remainingMinutes: 60,
          deadline: DateTime.now().add(const Duration(days: 2)),
        );

        final provider = MockScheduleProvider(ApiClient());
        provider.activeTasks = [task];
        provider.shouldFail = true;
        provider.lastApiException = ApiException(0, 'NETWORK_ERROR', 'Network connection timed out');

        await tester.pumpWidget(createTestApp(
          provider: provider,
          child: TaskProgressDialog(task: task, scheduledBlockMinutes: 30),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Made Progress'));
        await tester.pumpAndSettle();

        // Submit (fails with ambiguous network error)
        await tester.tap(find.text('Save Progress'));
        await tester.pumpAndSettle();

        expect(provider.recordProgressCalled, isTrue);
        expect(provider.isLastFailureAmbiguous, isTrue);

        // Ambiguous recovery banner is displayed
        expect(find.byKey(const Key('ambiguous_recovery_banner')), findsOneWidget);
        expect(find.byKey(const Key('retry_pending_button')), findsOneWidget);

        // Input TextField is locked
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);

        // SharedPreferences has persisted the pending operation without sensitive data
        final saved = await PendingOperationManager.getPendingOperation(task.id);
        expect(saved, isNotNull);
        expect(saved!.taskId, equals(task.id));
        expect(saved.action, equals('PROGRESS'));
        expect(saved.additionalMinutes, equals(30));
        expect(saved.operationId, equals(provider.recordedOperationIds.first));
      });

      testWidgets('Reopening dialog for task with ambiguous pending operation restores pending state and locks inputs', (tester) async {
        const pendingOpId = 'persisted-op-999';
        SharedPreferences.setMockInitialValues({});
        final task = Task(
          id: 'restored-task-2',
          userId: 'user-1',
          title: 'Restored Task',
          estimateMinutes: 90,
          completedMinutes: 0,
          actualMinutes: 0,
          remainingMinutes: 90,
          deadline: DateTime.now().add(const Duration(days: 1)),
        );

        // Pre-populate SharedPreferences with ambiguous pending completion
        await PendingOperationManager.savePendingOperation(
          PendingProgressOperation(
            taskId: task.id,
            operationId: pendingOpId,
            action: 'COMPLETE',
            actualMinutes: 75,
            remainingMinutes: 0,
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        final provider = MockScheduleProvider(ApiClient());
        provider.activeTasks = [task];

        await tester.pumpWidget(createTestApp(
          provider: provider,
          child: TaskProgressDialog(task: task, scheduledBlockMinutes: 45),
        ));
        await tester.pumpAndSettle();

        // Should automatically restore to Finished action form
        expect(find.text('Mark as Finished'), findsOneWidget);
        expect(find.text('75'), findsOneWidget);

        // Banner and retry button are visible
        expect(find.byKey(const Key('ambiguous_recovery_banner')), findsOneWidget);
        expect(find.byKey(const Key('retry_pending_button')), findsOneWidget);

        // TextField is locked
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isFalse);
      });

      testWidgets('Tapping "Retry Pending Update" reconciles server commit via getTaskOperation without re-running progress', (tester) async {
        const pendingOpId = 'reconcile-op-888';
        SharedPreferences.setMockInitialValues({});
        final task = Task(
          id: 'reconcile-task-3',
          userId: 'user-1',
          title: 'Reconcile Task',
          estimateMinutes: 60,
          completedMinutes: 0,
          actualMinutes: 0,
          remainingMinutes: 60,
          deadline: DateTime.now().add(const Duration(days: 1)),
        );

        await PendingOperationManager.savePendingOperation(
          PendingProgressOperation(
            taskId: task.id,
            operationId: pendingOpId,
            action: 'PROGRESS',
            additionalMinutes: 25,
            remainingMinutes: 35,
            status: 'IN_PROGRESS',
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ),
        );

        final provider = MockScheduleProvider(ApiClient());
        provider.activeTasks = [task];
        // Simulate server already committed this operation
        provider.operationStatusResult = {
          'operationId': pendingOpId,
          'taskId': task.id,
          'result': {'actualMinutes': 25, 'remainingMinutes': 35},
        };

        await tester.pumpWidget(createTestApp(
          provider: provider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TaskProgressDialog.show(context, task: task),
              child: const Text('Open Dialog'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('retry_pending_button')), findsOneWidget);

        // Tap Retry Pending Update
        await tester.ensureVisible(find.byKey(const Key('retry_pending_button')));
        await tester.tap(find.byKey(const Key('retry_pending_button')));
        await tester.pumpAndSettle();

        // getTaskOperation was queried
        expect(provider.operationStatusCalled, isTrue);
        // It did NOT re-execute progress mutation
        expect(provider.recordProgressCalled, isFalse);

        // Pending operation is cleared from local storage
        final remainingPending = await PendingOperationManager.getPendingOperation(task.id);
        expect(remainingPending, isNull);
      });

      testWidgets('Definite validation rejection (HTTP 400) clears pending lock and keeps inputs editable for user correction', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final task = Task(
          id: 'definite-reject-task-4',
          userId: 'user-1',
          title: 'Definite Reject Task',
          estimateMinutes: 60,
          completedMinutes: 0,
          actualMinutes: 0,
          remainingMinutes: 60,
          deadline: DateTime.now().add(const Duration(days: 2)),
        );

        final provider = MockScheduleProvider(ApiClient());
        provider.activeTasks = [task];
        provider.shouldFail = true;
        provider.lastApiException = ApiException(400, 'INVALID_INPUT', 'Minutes must be greater than zero');

        await tester.pumpWidget(createTestApp(
          provider: provider,
          child: TaskProgressDialog(task: task, scheduledBlockMinutes: 30),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Made Progress'));
        await tester.pumpAndSettle();

        // Submit (fails with definite 400 rejection)
        await tester.tap(find.text('Save Progress'));
        await tester.pumpAndSettle();

        expect(provider.recordProgressCalled, isTrue);
        expect(provider.isLastFailureAmbiguous, isFalse);

        // Recovery banner is NOT shown, regular error is shown
        expect(find.byKey(const Key('ambiguous_recovery_banner')), findsNothing);
        expect(find.text('Minutes must be greater than zero'), findsOneWidget);

        // TextField remains enabled for user correction
        final textField = tester.widget<TextField>(find.byType(TextField));
        expect(textField.enabled, isTrue);

        // Storage was cleared
        final pending = await PendingOperationManager.getPendingOperation(task.id);
        expect(pending, isNull);
      });

      testWidgets('Subsequent progress submission after confirmed success generates a fresh operationId', (tester) async {
        SharedPreferences.setMockInitialValues({});
        final task = Task(
          id: 'post-success-task-5',
          userId: 'user-1',
          title: 'Post Success Task',
          estimateMinutes: 90,
          completedMinutes: 0,
          actualMinutes: 0,
          remainingMinutes: 90,
          deadline: DateTime.now().add(const Duration(days: 2)),
        );

        final provider = MockScheduleProvider(ApiClient());
        provider.activeTasks = [task];

        await tester.pumpWidget(createTestApp(
          provider: provider,
          child: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => TaskProgressDialog.show(context, task: task, scheduledBlockMinutes: 30),
              child: const Text('Open Dialog'),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        // Session 1: Complete 30m progress
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Made Progress'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Progress'));
        await tester.pumpAndSettle();

        expect(provider.recordedOperationIds.length, equals(1));
        final op1 = provider.recordedOperationIds[0];

        // Storage is clean after confirmed success
        expect(await PendingOperationManager.getPendingOperation(task.id), isNull);

        // Session 2: User opens dialog again later to record another 20m
        await tester.tap(find.text('Open Dialog'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Made Progress'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save Progress'));
        await tester.pumpAndSettle();

        expect(provider.recordedOperationIds.length, equals(2));
        final op2 = provider.recordedOperationIds[1];

        // Clean new operation ID
        expect(op2, isNot(equals(op1)));
      });
    });
  });
}
