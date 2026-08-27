import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:equilibrium_app/core/api/api_client.dart';
import 'package:equilibrium_app/core/api/api_error_mapper.dart';
import 'package:equilibrium_app/core/state/auth_provider.dart';
import 'package:equilibrium_app/core/state/schedule_provider.dart';
import 'package:equilibrium_app/services/auth_repository.dart';
import 'package:equilibrium_app/services/schedule_repository.dart';
import 'package:equilibrium_app/services/task_repository.dart';
import 'package:equilibrium_app/models/schedule.dart';
import 'package:equilibrium_app/models/decision_log.dart';
import 'package:equilibrium_app/models/task.dart';
import 'package:equilibrium_app/widgets/status/error_state.dart';
import 'package:equilibrium_app/widgets/status/change_summary.dart';
import 'package:equilibrium_app/widgets/forms/explanation_sheet.dart';
import 'package:equilibrium_app/services/decision_repository.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:equilibrium_app/core/theme/theme.dart';

void main() {
  test('ApiException mapping for network failure', () {
    const code = 'NETWORK_ERROR';
    final message = ApiErrorMapper.getUserFacingMessage(code);
    expect(message, 'An unexpected communication error occurred. Please check your connection and try again.');
  });

  testWidgets('Logout state clearing', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final client = ApiClient(baseUrl: 'http://localhost');
    final authRepo = AuthRepository(client);
    final authProvider = AuthProvider(authRepo);
    
    // Simulate login by setting status
    // Since we cannot mock easily, we test if logout changes status eventually.
    authProvider.forceLogout();
    await tester.pumpAndSettle(const Duration(milliseconds: 100)); // allow async to complete
    
    expect(authProvider.status, AuthStatus.unauthenticated);
  });

  test('ScheduleProvider previous schedule handling', () {
    final client = ApiClient(baseUrl: 'http://localhost');
    final provider = ScheduleProvider(ScheduleRepository(client), TaskRepository(client));
    
    final s1 = ScheduleVersion(
      id: 'v1',
      horizonStart: DateTime.now(),
      horizonEnd: DateTime.now(),
      triggerType: 'MANUAL',
      blocks: [],
      decisionLogs: []
    );
    
    provider.currentSchedule = s1;
    provider.previousSchedule = provider.currentSchedule;
    
    expect(provider.previousSchedule?.id, 'v1');
    provider.clearChangeSummary();
    expect(provider.previousSchedule, null);
  });

  testWidgets('ExplanationSheet empty state', (WidgetTester tester) async {
    final client = ApiClient(baseUrl: 'http://localhost');
    final task = Task(
      id: 't1', title: 'T1', estimateMinutes: 60, completedMinutes: 0,
      remainingMinutes: 60, deadline: DateTime.now(), cognitiveLoad: CognitiveLoad.medium,
      status: TaskStatus.scheduled
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => DecisionRepository(client)),
        ],
        child: MaterialApp(
          theme: EqTheme.lightTheme,
          home: Scaffold(
            body: ExplanationSheet(task: task, versionId: 'v1'),
          ),
        ),
      ),
    );

    // Let the network call fail immediately or eventually
    await tester.pumpAndSettle();

    // Should show error state since it's a fake URL
    expect(find.textContaining('load the scheduling explanation'), findsOneWidget);
  });
}
