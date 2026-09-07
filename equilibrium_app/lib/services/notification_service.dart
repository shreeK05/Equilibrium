import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/schedule.dart';
import '../models/task.dart';

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    tz.initializeTimeZones();
    final timezone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezone.identifier));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings: settings);
    if (Platform.isAndroid) {
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
    _initialized = true;
  }

  Future<void> scheduleTasks(ScheduleVersion? schedule, List<Task> tasks) async {
    if (!_initialized || schedule == null) return;
    await _plugin.cancelAll();
    final preferences = await SharedPreferences.getInstance();
    if (preferences.getBool('upcoming_task_alerts') == false) return;
    final taskTitles = {for (final task in tasks) task.id: task.title};
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'equilibrium_tasks',
        'Equilibrium tasks',
        channelDescription: 'Reminders for scheduled study blocks',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );

    for (final block in schedule.blocks.where((block) => block.type == 'TASK' && block.taskId != null)) {
      final reminder = block.startTime.subtract(const Duration(minutes: 10));
      if (!reminder.isAfter(DateTime.now())) continue;
      await _plugin.zonedSchedule(
        id: block.id.hashCode & 0x7fffffff,
        title: 'Starting soon',
        body: taskTitles[block.taskId] ?? 'Scheduled study block',
        scheduledDate: tz.TZDateTime.from(reminder, tz.local),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
