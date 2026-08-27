import '../../core/api/api_client.dart';
import '../../models/schedule.dart';

class ScheduleRepository {
  final ApiClient _api;

  ScheduleRepository(this._api);

  Future<ScheduleVersion?> getCurrentSchedule() async {
    try {
      final data = await _api.get('/schedules/current');
      if (data == null) return null;
      return ScheduleVersion.fromJson(data);
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        return null; // Return null gracefully if no schedule is found
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
