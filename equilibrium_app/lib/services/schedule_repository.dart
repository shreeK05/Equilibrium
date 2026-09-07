import '../../core/api/api_client.dart';
import '../../models/schedule.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ScheduleRepository {
  final ApiClient _api;

  ScheduleRepository(this._api);

  Future<ScheduleVersion?> getCurrentSchedule() async {
    try {
      final data = await _api.get('/schedules/current');
      if (data == null) return null;
      final schedule = ScheduleVersion.fromJson(data as Map<String, dynamic>);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cached_schedule', jsonEncode(schedule.toJson()));
      return schedule;
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        return null; // Return null gracefully if no schedule is found
      }
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString('cached_schedule');
      if (cached != null) {
        return ScheduleVersion.fromJson(jsonDecode(cached) as Map<String, dynamic>);
      }
      rethrow;
    }
  }

  Future<void> generateSchedule() async {
    await _api.post('/schedules/generate');
  }

  Future<ScheduleVersion> reschedule(String versionId) async {
    final data = await _api.post('/schedules/$versionId/reschedule');
    return ScheduleVersion.fromJson(data);
  }
}
