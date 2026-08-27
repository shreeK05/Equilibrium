import 'package:flutter/foundation.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import '../../services/schedule_repository.dart';
import '../../services/task_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_error_mapper.dart';

class ScheduleProvider extends ChangeNotifier {
  final ScheduleRepository _scheduleRepo;
  final TaskRepository _taskRepo;

  ScheduleVersion? currentSchedule;
  List<Task> activeTasks = [];
  bool isLoading = false;
  String? errorMessage;
  String? errorCode;

  ScheduleProvider(this._scheduleRepo, this._taskRepo);

  Future<void> fetchDashboardData() async {
    _setLoading(true);
    try {
      final futures = await Future.wait([
        _scheduleRepo.getCurrentSchedule(),
        _taskRepo.getTasks(),
      ]);
      
      currentSchedule = futures[0] as ScheduleVersion?;
      activeTasks = futures[1] as List<Task>;
      errorMessage = null;
      errorCode = null;
    } on ApiException catch (e) {
      errorCode = e.code;
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
    } catch (e) {
      errorCode = 'INTERNAL_ERROR';
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> createTask(Map<String, dynamic> payload) async {
    _setLoading(true);
    try {
      await _taskRepo.createTask(payload);
      await fetchDashboardData(); // Refresh seamlessly
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    _setLoading(true);
    try {
      await _taskRepo.updateTask(id, updates);
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteTask(String id) async {
    _setLoading(true);
    try {
      await _taskRepo.deleteTask(id);
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  ScheduleVersion? previousSchedule;

  Future<bool> generateSchedule() async {
    _setLoading(true);
    try {
      await _scheduleRepo.generateSchedule();
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> reschedule() async {
    if (currentSchedule == null) return false;
    _setLoading(true);
    try {
      // Capture the current schedule as previous before we fetch the new one
      previousSchedule = currentSchedule;
      await _scheduleRepo.reschedule(currentSchedule!.id);
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  void clearChangeSummary() {
    previousSchedule = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
