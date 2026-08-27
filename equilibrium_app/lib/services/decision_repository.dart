import '../models/decision_log.dart';
import '../core/api/api_client.dart';

class DecisionRepository {
  final ApiClient _apiClient;

  DecisionRepository(this._apiClient);

  Future<List<DecisionLog>> getDecisions(String scheduleId) async {
    final response = await _apiClient.get('/schedules/$scheduleId/decisions');
    final List<dynamic> data = response.data;
    return data.map((json) => DecisionLog.fromJson(json)).toList();
  }
}
