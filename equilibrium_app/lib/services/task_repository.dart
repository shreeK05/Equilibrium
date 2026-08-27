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
}
