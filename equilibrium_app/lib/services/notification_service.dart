import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule.dart';
import '../models/task.dart';

typedef NotificationActionCallback = void Function(String actionId, String? payload);

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  NotificationActionCallback? onActionTriggered;

  // Active scheduled notification IDs for deduplication
  final Set<int> _scheduledIds = {};

  Future<void> initialize({NotificationActionCallback? onAction}) async {
    if (_initialized || kIsWeb) return;
    onActionTriggered = onAction;

    try {
      tz.initializeTimeZones();
      final timezone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezone.identifier));
    } catch (e) {
      // Fallback if local timezone lookup fails
      tz.initializeTimeZones();
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );

    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        final actionId = response.actionId ?? 'tap';
        final payload = response.payload;
        if (actionId == 'snooze_15' && payload != null) {
          // Handle snooze locally
          snoozeTask(response.id ?? 1001, 'Snoozed Task', payload, minutes: 15);
        }
        onActionTriggered?.call(actionId, payload);
      },
    );

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  /// Cancels all previously scheduled task alerts for clean deduplication
  Future<void> cancelAll() async {
    if (!_initialized) return;
    await _plugin.cancelAll();
    _scheduledIds.clear();
  }

  /// Schedules upcoming study blocks and approaching deadlines
  Future<void> scheduleTasks(ScheduleVersion? schedule, List<Task> tasks) async {
    if (!_initialized || schedule == null) return;
    await cancelAll();

    final preferences = await SharedPreferences.getInstance();
    final enableTaskAlerts = preferences.getBool('upcoming_task_alerts') ?? true;
    final enableDeadlineAlerts = preferences.getBool('deadline_alerts') ?? true;
    final leadMinutes = preferences.getInt('reminder_lead_minutes') ?? 10;

    final taskTitles = {for (final task in tasks) task.id: task.title};

    // 1. Upcoming Study Sessions Notification Details
    final sessionDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'equilibrium_sessions',
        'Study Sessions',
        channelDescription: 'Actionable reminders for upcoming scheduled study blocks',
        importance: Importance.high,
        priority: Priority.high,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction('start_now', 'Start Now', showsUserInterface: true),
          AndroidNotificationAction('snooze_15', 'Snooze 15m', cancelNotification: true),
          AndroidNotificationAction('reschedule', 'Reschedule', showsUserInterface: true),
        ],
      ),
      iOS: const DarwinNotificationDetails(),
    );

    // 2. Deadline Notification Details
    final deadlineDetails = NotificationDetails(
      android: AndroidNotificationDetails(
        'equilibrium_deadlines',
        'Task Deadlines',
        channelDescription: 'Alerts for approaching assignments and academic deadlines',
        importance: Importance.high,
        priority: Priority.high,
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction('start_now', 'Work on Task', showsUserInterface: true),
          AndroidNotificationAction('reschedule', 'Reschedule', showsUserInterface: true),
        ],
      ),
      iOS: const DarwinNotificationDetails(),
    );

    final now = DateTime.now();

    // Schedule study session alerts
    if (enableTaskAlerts) {
      for (final block in schedule.blocks.where((b) => b.type == 'TASK' && b.taskId != null)) {
        final reminder = block.startTime.subtract(Duration(minutes: leadMinutes));
        if (!reminder.isAfter(now)) continue;

        final notificationId = (block.id.hashCode & 0x7fffffff) % 100000;
        if (_scheduledIds.contains(notificationId)) continue;
        _scheduledIds.add(notificationId);

        final taskName = taskTitles[block.taskId] ?? 'Scheduled study block';

        await _plugin.zonedSchedule(
          id: notificationId,
          title: 'Study Session in $leadMinutes mins',
          body: '$taskName is scheduled at ${_formatTime(block.startTime)}',
          scheduledDate: tz.TZDateTime.from(reminder, tz.local),
          notificationDetails: sessionDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: block.taskId,
        );
      }
    }

    // Schedule deadline alerts (2 hours before due date)
    if (enableDeadlineAlerts) {
      for (final task in tasks.where((t) => t.status != TaskStatus.completed && t.remainingMinutes > 0)) {
        final deadlineAlertTime = task.deadline.subtract(const Duration(hours: 2));
        if (!deadlineAlertTime.isAfter(now)) continue;

        final deadlineNotificationId = ((task.id.hashCode & 0x7fffffff) + 500000) % 1000000;
        if (_scheduledIds.contains(deadlineNotificationId)) continue;
        _scheduledIds.add(deadlineNotificationId);

        await _plugin.zonedSchedule(
          id: deadlineNotificationId,
          title: 'Deadline Approaching',
          body: "'${task.title}' is due in 2 hours (${_formatTime(task.deadline)})",
          scheduledDate: tz.TZDateTime.from(deadlineAlertTime, tz.local),
          notificationDetails: deadlineDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: task.id,
        );
      }
    }
  }

  /// Snoozes a reminder for [minutes]
  Future<void> snoozeTask(int id, String title, String taskId, {int minutes = 15}) async {
    if (!_initialized) return;
    final snoozeDate = DateTime.now().add(Duration(minutes: minutes));

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'equilibrium_reminders',
        'Snoozed Reminders',
        channelDescription: 'Snoozed notifications for deferred tasks',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('start_now', 'Start Now', showsUserInterface: true),
          AndroidNotificationAction('reschedule', 'Reschedule', showsUserInterface: true),
        ],
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.zonedSchedule(
      id: (id + 100000) % 1000000,
      title: 'Reminder: $title',
      body: 'Ready to continue your focus session?',
      scheduledDate: tz.TZDateTime.from(snoozeDate, tz.local),
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: taskId,
    );
  }

  String _formatTime(DateTime dt) {
    final hr = dt.hour.toString().padLeft(2, '0');
    final mn = dt.minute.toString().padLeft(2, '0');
    return '$hr:$mn';
  }
}
