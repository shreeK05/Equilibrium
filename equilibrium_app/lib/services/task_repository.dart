import '../../core/api/api_client.dart';
import '../../models/task.dart';

class TaskRepository {
  final ApiClient _api;

  TaskRepository(this._api);

  Future<List<Task>> getTasks() async {
    final data = await _api.get('/tasks') as List;
    return data.map((json) => Task.fromJson(json as Map<String, dynamic>)).toList();
  }

  Future<Task> createTask(Map<String, dynamic> payload) async {
    final data = await _api.post('/tasks', body: payload);
    return Task.fromJson(data);
  }

  Future<Task> updateTask(String id, Map<String, dynamic> updates) async {
    final data = await _api.patch('/tasks/$id', body: updates);
    return Task.fromJson(data);
  }

  Future<void> deleteTask(String id) async {
    await _api.delete('/tasks/$id');
  }

  Future<Task> completeTask(String id, [int? actualMinutes, String? operationId]) async {
    final body = <String, dynamic>{};
    if (actualMinutes != null) body['actualMinutes'] = actualMinutes;
    if (operationId != null) body['operationId'] = operationId;
    final data = await _api.post('/tasks/$id/complete', body: body);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<Task> recordProgress(
    String id, {
    int? completedMinutes,
    int? additionalMinutes,
    int? actualMinutes,
    int? remainingMinutes,
    int? newEstimateMinutes,
    String? status,
    String? operationId,
  }) async {
    final body = <String, dynamic>{};
    if (completedMinutes != null) body['completedMinutes'] = completedMinutes;
    if (additionalMinutes != null) body['additionalMinutes'] = additionalMinutes;
    if (actualMinutes != null) body['actualMinutes'] = actualMinutes;
    if (remainingMinutes != null) body['remainingMinutes'] = remainingMinutes;
    if (newEstimateMinutes != null) body['newEstimateMinutes'] = newEstimateMinutes;
    if (status != null) body['status'] = status;
    if (operationId != null) body['operationId'] = operationId;
    final data = await _api.post('/tasks/$id/progress', body: body);
    return Task.fromJson(data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>?> getOperation(String taskId, String operationId) async {
    try {
      final data = await _api.get('/tasks/$taskId/operations/$operationId');
      return data as Map<String, dynamic>?;
    } catch (e) {
      if (e is ApiException && e.statusCode == 404) {
        return null;
      }
      rethrow;
    }
  }
}

