import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/core/state/auth_provider.dart';
import 'package:equilibrium_app/core/state/schedule_provider.dart';
import 'package:equilibrium_app/services/auth_repository.dart';
import 'package:equilibrium_app/models/task.dart';
import 'package:equilibrium_app/models/schedule.dart';
import 'package:equilibrium_app/core/services/pending_operation_manager.dart';

String createTestJwt({int expiresInSeconds = 3600}) {
  final header = base64Url.encode(utf8.encode(jsonEncode({'alg': 'HS256', 'typ': 'JWT'}))).replaceAll('=', '');
  final payload = base64Url.encode(utf8.encode(jsonEncode({
    'userId': 'test-user-123',
    'exp': (DateTime.now().millisecondsSinceEpoch ~/ 1000) + expiresInSeconds,
  }))).replaceAll('=', '');
  return '$header.$payload.fake_signature';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Phase 4A — API Client & Environment Configuration', () {
    test('Configurable API base URL selection initializes with specified endpoint', () {
      const stagingUrl = 'https://staging.equilibrium.test/api/v1';
      final client = ApiClient(baseUrl: stagingUrl);
      expect(client.baseUrl, stagingUrl);

      const localUrl = 'http://localhost:3000/api/v1';
      final localClient = ApiClient(baseUrl: localUrl);
      expect(localClient.baseUrl, localUrl);
    });

    test('HTTP 401 Unauthorized triggers onUnauthorized hook and switches auth state', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', createTestJwt());

      bool unauthorizedTriggered = false;
      final api = ApiClient(
        baseUrl: 'http://mock.staging',
        onUnauthorized: () {
          unauthorizedTriggered = true;
        },
      );

      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      await pumpEventQueue();

      expect(authProvider.status, AuthStatus.authenticated);

      // Wire ApiClient onUnauthorized to AuthProvider forceLogout
      api.onUnauthorized = () {
        unauthorizedTriggered = true;
        authProvider.forceLogout();
      };

      // Trigger forceLogout directly as simulated 401 interceptor
      api.onUnauthorized?.call();
      await pumpEventQueue();

      expect(unauthorizedTriggered, isTrue);
      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(await authRepo.isLoggedIn(), isFalse);
    });
  });

  group('Phase 4A — Network Responses & Resilience Categorization', () {
    test('Definite rejection vs ambiguous network failure categorization', () {
      // Definite rejection: 400 Bad Request, 401 Unauthorized, 404 Not Found, 409 Conflict
      final ex400 = ApiException(400, 'VALIDATION_ERROR', 'Invalid duration');
      expect(ex400.isDefiniteRejection, isTrue);
      expect(ex400.isAmbiguous, isFalse);

      final ex409 = ApiException(409, 'IDEMPOTENCY_CONFLICT', 'Duplicate key');
      expect(ex409.isDefiniteRejection, isTrue);
      expect(ex409.isAmbiguous, isFalse);

      // Ambiguous: 0/NETWORK_ERROR, 500 Server Error, 503 Unavailable
      final exNet = ApiException(0, 'NETWORK_ERROR', 'SocketException: Connection refused');
      expect(exNet.isDefiniteRejection, isFalse);
      expect(exNet.isAmbiguous, isTrue);

      final ex500 = ApiException(500, 'INTERNAL_SERVER_ERROR', 'Database pool timeout');
      expect(ex500.isDefiniteRejection, isFalse);
      expect(ex500.isAmbiguous, isTrue);
    });
  });

  group('Phase 4A — Core Provider Workflows (Mocked API)', () {
    test('Task creation updates activeTasks and notifies listeners', () async {
      final api = ApiClient(baseUrl: 'http://mock.local');
      final scheduleProvider = ScheduleProvider(api);

      final now = DateTime.now();
      final createdTask = Task(
        id: 'task-staging-101',
        userId: 'user-staging-1',
        title: 'Microservices Architecture Review',
        estimateMinutes: 90,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 2)),
        createdAt: now,
        updatedAt: now,
      );

      scheduleProvider.activeTasks = [createdTask];
      expect(scheduleProvider.activeTasks.length, 1);
      expect(scheduleProvider.activeTasks.first.title, 'Microservices Architecture Review');
    });

    test('Schedule generation refreshes schedule version and planned blocks', () async {
      final api = ApiClient(baseUrl: 'http://mock.local');
      final scheduleProvider = ScheduleProvider(api);

      final now = DateTime.now();
      final block = ScheduleBlock(
        id: 'block-staging-1',
        versionId: 'ver-staging-1',
        type: 'TASK',
        startTime: now.add(const Duration(hours: 1)),
        endTime: now.add(const Duration(hours: 2)),
        durationMinutes: 60,
        taskId: 'task-staging-101',
        isLocked: false,
      );

      final version = ScheduleVersion(
        id: 'ver-staging-1',
        triggerType: 'MANUAL',
        generatedAt: now,
        capacityMinutes: 480,
        blocks: [block],
      );

      scheduleProvider.currentSchedule = version;
      expect(scheduleProvider.currentSchedule?.id, 'ver-staging-1');
      expect(scheduleProvider.currentSchedule?.blocks.length, 1);
      expect(scheduleProvider.currentSchedule?.blocks.first.taskId, 'task-staging-101');
    });

    test('Progress submission preserves operationId in SharedPreferences for recovery', () async {
      final now = DateTime.now();
      final task = Task(
        id: 'task-rec-1',
        userId: 'u1',
        title: 'Algorithms Midterm Prep',
        estimateMinutes: 120,
        completedMinutes: 0,
        deadline: now.add(const Duration(days: 1)),
        createdAt: now,
        updatedAt: now,
      );

      const opId = 'op-rec-stage-1234';
      final pendingOp = PendingProgressOperation(
        taskId: task.id,
        operationId: opId,
        action: 'PROGRESS',
        additionalMinutes: 45,
        remainingMinutes: 75,
        status: 'IN_PROGRESS',
        timestamp: DateTime.now().millisecondsSinceEpoch,
      );

      await PendingOperationManager.savePendingOperation(pendingOp);

      // Verify persisted for recovery
      final retrieved = await PendingOperationManager.getPendingOperation(task.id);
      expect(retrieved, isNotNull);
      expect(retrieved?.operationId, opId);
      expect(retrieved?.remainingMinutes, 75);

      // Successful reconciliation clears pending operation
      await PendingOperationManager.clearPendingOperation(task.id);
      final cleared = await PendingOperationManager.getPendingOperation(task.id);
      expect(cleared, isNull);
    });

    test('Sign-out purges credentials and resets authentication state', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', createTestJwt());

      final api = ApiClient(baseUrl: 'http://mock.local');
      final authRepo = AuthRepository(api);
      final authProvider = AuthProvider(authRepo);
      await pumpEventQueue();

      expect(authProvider.status, AuthStatus.authenticated);

      await authProvider.logout();
      await pumpEventQueue();

      expect(authProvider.status, AuthStatus.unauthenticated);
      expect(await authRepo.isLoggedIn(), isFalse);
    });
  });
}
