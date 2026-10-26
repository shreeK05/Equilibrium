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
import 'package:equilibrium_app/widgets/forms/conversational_task_sheet.dart';
import 'package:equilibrium_app/widgets/dialogs/conversational_reschedule_dialog.dart';
import 'package:equilibrium_app/screens/routines/routines_screen.dart';
import 'package:equilibrium_app/screens/schedule/weekly_schedule_screen.dart';
import 'package:equilibrium_app/screens/imports/timetable_import_screen.dart';
import 'package:equilibrium_app/services/ocr_service.dart';

class MockScheduleProvider extends ScheduleProvider {
  MockScheduleProvider(super.api);

  @override
  Future<void> fetchDashboardData() async {
    notifyListeners();
  }

  @override
  Future<List<Map<String, dynamic>>> getRoutines() async {
    return [
      {
        'id': 'routine_breakfast',
        'title': 'Breakfast',
        'startTime': '08:00',
        'endTime': '08:45',
        'isEnabled': true,
        'category': 'MEAL',
      },
      {
        'id': 'routine_lunch',
        'title': 'Lunch',
        'startTime': '13:00',
        'endTime': '14:00',
        'isEnabled': true,
        'category': 'MEAL',
      },
      {
        'id': 'routine_evening_break',
        'title': 'Evening Break / Exercise',
        'startTime': '17:30',
        'endTime': '18:00',
        'isEnabled': true,
        'category': 'BREAK',
      },
      {
        'id': 'routine_dinner',
        'title': 'Dinner',
        'startTime': '20:00',
        'endTime': '21:00',
        'isEnabled': true,
        'category': 'MEAL',
      },
    ];
  }
}

class MockExamProvider extends ExamProvider {
  MockExamProvider(super.api);

  @override
  Future<void> fetchAll() async {}
}

class MockOcrService implements IOcrService {
  final String textToReturn;
  MockOcrService({required this.textToReturn});

  @override
  Future<String> recognizeTextFromFile(String filePath) async => textToReturn;

  @override
  Future<String> recognizeTextFromBytes(dynamic bytes) async => textToReturn;

  @override
  Future<void> dispose() async {}
}

class MockOcrApiClient extends ApiClient {
  MockOcrApiClient() : super(baseUrl: 'http://localhost');

  bool parseCalled = false;
  bool confirmCalled = false;
  dynamic lastConfirmedBody;

  @override
  Future<dynamic> post(String path, {dynamic body}) async {
    if (path == '/imports/timetable/parse') {
      parseCalled = true;
      return {
        'jobId': 'ocr-job-123',
        'candidateCount': 3,
        'candidates': [
          {
            'id': 'cand-1',
            'dayOfWeek': 1,
            'dayName': 'Monday',
            'startTime': '09:00',
            'endTime': '10:00',
            'subject': 'Database Management Systems',
            'venue': 'Room 302',
            'confidence': 0.95,
            'isUncertain': false,
            'isDuplicate': false,
            'rawText': 'Monday 09:00 - 10:00 Database Management Systems Room 302'
          },
          {
            'id': 'cand-2',
            'dayOfWeek': 2,
            'dayName': 'Tuesday',
            'startTime': '11:15',
            'endTime': '12:15',
            'subject': 'Computer Networks',
            'venue': 'LH-1',
            'confidence': 0.5,
            'isUncertain': true,
            'uncertaintyReason': 'Low OCR confidence',
            'isDuplicate': false,
            'rawText': 'Tuesday 11:15 - 12:15 Computer Networks LH-1'
          },
          {
            'id': 'cand-3',
            'dayOfWeek': 3,
            'dayName': 'Wednesday',
            'startTime': '14:00',
            'endTime': '16:00',
            'subject': 'Operating Systems Lab',
            'venue': 'Lab 3',
            'confidence': 0.9,
            'isUncertain': false,
            'isDuplicate': true,
            'rawText': 'Wednesday 14:00 - 16:00 Operating Systems Lab Lab 3'
          }
        ]
      };
    }
    if (path.contains('/confirm')) {
      confirmCalled = true;
      lastConfirmedBody = body;
      return {
        'message': 'Successfully imported 3 timetable class(es)',
        'importedCount': 3
      };
    }
    return {};
  }
}

Widget createTestApp({
  required Widget home,
  required ScheduleProvider scheduleProvider,
  ApiClient? api,
}) {
  final testApi = api ?? ApiClient(baseUrl: 'http://localhost:3000/api/v1');
  return MultiProvider(
    providers: [
      Provider<ApiClient>.value(value: testApi),
      ChangeNotifierProvider<ScheduleProvider>.value(value: scheduleProvider),
      ChangeNotifierProvider<ProfileProvider>.value(value: ProfileProvider(testApi)),
      ChangeNotifierProvider<TimerProvider>.value(value: TimerProvider(testApi)),
      ChangeNotifierProvider<ExamProvider>.value(value: MockExamProvider(testApi)),
    ],
    child: MaterialApp(
      theme: EqTheme.lightTheme,
      darkTheme: EqTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: home,
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Milestone 2: Conversational Task Creation & Rescheduling UX', () {
    testWidgets('ConversationalTaskSheet renders NLP input and quick example chips', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: ConversationalTaskSheet()),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Natural Language Task Entry'), findsOneWidget);
      expect(find.byType(TextField), findsWidgets);
      expect(find.text('Suggestions:'), findsOneWidget);
      expect(find.text('DBMS assignment tomorrow by 5 PM, 90 mins, high priority'), findsOneWidget);
    });

    testWidgets('ConversationalRescheduleSheet renders common intent chips and text box', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const Scaffold(body: ConversationalRescheduleSheet()),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Conversational Rescheduling'), findsOneWidget);
      expect(find.text('I am unable to study tonight'), findsOneWidget);
      expect(find.text('I have only 1 hour free today'), findsOneWidget);
      expect(find.text('Analyze & Propose Solution'), findsOneWidget);
    });
  });

  group('Milestone 3: Daily Routines & Meal Protection', () {
    testWidgets('RoutinesScreen loads and displays protected meal and break blocks', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const RoutinesScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Meals & Daily Routines'), findsOneWidget);
      expect(find.text('Breakfast'), findsOneWidget);
      expect(find.text('Lunch'), findsOneWidget);
      expect(find.text('Dinner'), findsOneWidget);
    });
  });

  group('Milestone 4: College Timetable Import OCR', () {
    testWidgets('TimetableImportScreen renders photo scanner mode and paste options', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);

      await tester.pumpWidget(createTestApp(
        home: const TimetableImportScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Import College Timetable'), findsOneWidget);
      expect(find.text('Select Image'), findsOneWidget);
      expect(find.text('Parse Text'), findsOneWidget);
    });

    testWidgets('TimetableImportScreen parses OCR text and displays editable candidates with uncertainty flags', (tester) async {
      final mockApi = MockOcrApiClient();
      final scheduleProvider = MockScheduleProvider(mockApi);
      const representativeOcrText = """
Monday 09:00 - 10:00 Database Management Systems Room 302
Tuesday 11:15 - 12:15 Computer Networks LH-1
Wednesday 14:00 - 16:00 Operating Systems Lab Lab 3
""";
      final mockOcr = MockOcrService(textToReturn: representativeOcrText);

      await tester.pumpWidget(createTestApp(
        home: TimetableImportScreen(ocrService: mockOcr),
        scheduleProvider: scheduleProvider,
        api: mockApi,
      ));
      await tester.pumpAndSettle();

      // Enter representative OCR text directly into the text field and click Parse Text
      final textField = find.byType(TextField);
      await tester.enterText(textField, representativeOcrText);
      await tester.pumpAndSettle();

      final parseButton = find.widgetWithText(OutlinedButton, 'Parse Text');
      await tester.tap(parseButton);
      await tester.pumpAndSettle();

      expect(mockApi.parseCalled, isTrue);

      // Verify candidates displayed
      expect(find.text('Extracted Classes (3)'), findsOneWidget);
      expect(find.text('Database Management Systems'), findsOneWidget);
      expect(find.text('Computer Networks'), findsOneWidget);
      expect(find.text('Operating Systems Lab'), findsOneWidget);

      // Verify uncertainty and duplicate badges
      expect(find.text('Verify'), findsOneWidget); // For candidate 2
      expect(find.text('Duplicate'), findsOneWidget); // For candidate 3

      // Verify confirm button is active with candidate count
      expect(find.text('Confirm & Save Timetable (3)'), findsOneWidget);
    });

    testWidgets('TimetableImportScreen allows inline editing of candidate and confirmation', (tester) async {
      final mockApi = MockOcrApiClient();
      final scheduleProvider = MockScheduleProvider(mockApi);
      const representativeOcrText = "Monday 09:00 - 10:00 Database Management Systems Room 302";
      final mockOcr = MockOcrService(textToReturn: representativeOcrText);

      await tester.pumpWidget(createTestApp(
        home: TimetableImportScreen(ocrService: mockOcr),
        scheduleProvider: scheduleProvider,
        api: mockApi,
      ));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), representativeOcrText);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Parse Text'));
      await tester.pumpAndSettle();

      // Tap the edit icon on the first candidate
      final editIcon = find.byIcon(Icons.edit_outlined).first;
      await tester.tap(editIcon);
      await tester.pumpAndSettle();

      // Verify edit dialog is open
      expect(find.text('Edit Timetable Row'), findsOneWidget);

      // Edit subject name
      final subjectField = find.widgetWithText(TextField, 'Database Management Systems');
      await tester.enterText(subjectField, 'Advanced DBMS');
      await tester.pumpAndSettle();

      // Save row
      await tester.tap(find.text('Save Row'));
      await tester.pumpAndSettle();

      // Check updated subject is reflected
      expect(find.text('Advanced DBMS'), findsOneWidget);

      // Delete first item (which is safely on screen)
      final deleteIcon = find.byIcon(Icons.delete_outline).first;
      await tester.ensureVisible(deleteIcon);
      await tester.tap(deleteIcon);
      await tester.pumpAndSettle();

      expect(find.text('Extracted Classes (2)'), findsOneWidget);

      // Confirm & Save
      final confirmBtn = find.text('Confirm & Save Timetable (2)');
      await tester.ensureVisible(confirmBtn);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockApi.confirmCalled, isTrue);
    });
  });

  group('Milestone 5: 7-Day Weekly Workload Planner', () {
    testWidgets('WeeklyScheduleScreen renders 7-day strip and daily time blocks', (tester) async {
      final api = ApiClient(baseUrl: 'http://localhost');
      final scheduleProvider = MockScheduleProvider(api);
      final now = DateTime.now();

      scheduleProvider.currentSchedule = ScheduleVersion(
        id: 'v1',
        triggerType: 'MANUAL',
        generatedAt: now,
        capacityMinutes: 480,
        blocks: [
          ScheduleBlock(
            id: 'b-week-1',
            versionId: 'v1',
            type: 'TASK',
            startTime: DateTime(now.year, now.month, now.day, 10, 0),
            endTime: DateTime(now.year, now.month, now.day, 11, 30),
            durationMinutes: 90,
            taskId: 't-week-1',
            isLocked: false,
          ),
        ],
      );
      scheduleProvider.activeTasks = [
        Task(
          id: 't-week-1',
          userId: 'u1',
          title: 'Weekly Math Preparation',
          estimateMinutes: 90,
          completedMinutes: 0,
          deadline: now.add(const Duration(days: 3)),
          createdAt: now,
          updatedAt: now,
        ),
      ];

      await tester.pumpWidget(createTestApp(
        home: const WeeklyScheduleScreen(),
        scheduleProvider: scheduleProvider,
      ));
      await tester.pumpAndSettle();

      expect(find.text('7-Day Workload Planner'), findsOneWidget);
      expect(find.text('Weekly Math Preparation'), findsOneWidget);
      expect(find.text('90m total scheduled'), findsOneWidget);
    });
  });
}
