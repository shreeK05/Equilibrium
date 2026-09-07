import 'package:flutter/foundation.dart';
import '../../models/schedule.dart';
import '../../models/task.dart';
import '../../models/commitment.dart';
import '../../services/schedule_repository.dart';
import '../../services/task_repository.dart';
import '../../services/commitment_repository.dart';
import '../../services/constraint_repository.dart';
import '../../core/api/api_client.dart';
import '../../core/api/api_error_mapper.dart';

class ScheduleProvider extends ChangeNotifier {
  final ScheduleRepository _scheduleRepo;
  final TaskRepository _taskRepo;
  final CommitmentRepository _commitmentRepo;
  final ConstraintRepository _constraintRepo;
  final ApiClient _api;

  ScheduleVersion? currentSchedule;
  ScheduleVersion? previousSchedule;
  List<Task> activeTasks = [];
  List<FixedCommitment> commitments = [];
  Map<String, dynamic>? constraints;
  Map<String, dynamic>? insights;
  bool isLoading = false;
  String? errorMessage;
  String? errorCode;

  ScheduleProvider(ApiClient api) 
    : _api = api,
      _scheduleRepo = ScheduleRepository(api),
        _taskRepo = TaskRepository(api),
        _commitmentRepo = CommitmentRepository(api),
        _constraintRepo = ConstraintRepository(api);

  Future<void> fetchDashboardData() async {
    _setLoading(true);
    try {
      final futures = await Future.wait([
        _scheduleRepo.getCurrentSchedule(),
        _taskRepo.getTasks(),
        _commitmentRepo.getCommitments(),
        _constraintRepo.getConstraints(),
      ]);
      
      currentSchedule = futures[0] as ScheduleVersion?;
      activeTasks = futures[1] as List<Task>;
      commitments = futures[2] as List<FixedCommitment>;
      constraints = futures[3] as Map<String, dynamic>;
      try {
        insights = await _api.get('/insights') as Map<String, dynamic>;
      } catch (_) {
        insights = null;
      }
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

  Future<bool> createCommitment(Map<String, dynamic> payload) async {
    _setLoading(true);
    try {
      await _commitmentRepo.createCommitment(payload);
      await generateSchedule(); // Regenerate immediately to respect the new hard constraint!
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

  Future<bool> deleteCommitment(String id) async {
    _setLoading(true);
    try {
      await _commitmentRepo.deleteCommitment(id);
      await generateSchedule(); // Regenerate immediately to reclaim the capacity
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

  Future<bool> completeTask(String id, int actualMinutes) async {
    _setLoading(true);
    try {
      await _taskRepo.completeTask(id, actualMinutes);
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
