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
import 'package:intl/intl.dart';
import '../../models/decision_log.dart';
import '../../services/notification_service.dart';

class ReplanSummary {
  final int scheduledTaskCount;
  final int totalScheduledMinutes;
  final int deferredTaskCount;
  final List<String> deferredTaskTitles;
  final bool hasDeferred;
  final String userMessage;

  const ReplanSummary({
    required this.scheduledTaskCount,
    required this.totalScheduledMinutes,
    required this.deferredTaskCount,
    required this.deferredTaskTitles,
    required this.hasDeferred,
    required this.userMessage,
  });
}

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
  DateTime selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  bool isLoading = false;
  String? errorMessage;
  String? errorCode;
  ApiException? lastApiException;
  bool isLastFailureAmbiguous = false;

  TaskRepository get taskRepo => _taskRepo;

  Future<Map<String, dynamic>?> getTaskOperation(String taskId, String operationId) async {
    return _taskRepo.getOperation(taskId, operationId);
  }

  bool get hasContentForSelectedDate {
    if (currentSchedule == null) return false;
    final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
    final hasBlocksForDay = (currentSchedule?.blocks ?? <ScheduleBlock>[]).any((b) => DateFormat('yyyy-MM-dd').format(b.startTime) == selectedDateStr);
    final hasCommitmentsForDay = commitments.any((c) => DateFormat('yyyy-MM-dd').format(c.startTime) == selectedDateStr);
    return hasBlocksForDay || hasCommitmentsForDay;
  }

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
      await NotificationService.instance.scheduleTasks(currentSchedule, activeTasks);
      try {
        insights = await _api.get('/insights') as Map<String, dynamic>;
      } catch (_) {
        insights = null;
      }
      errorMessage = null;
      errorCode = null;
    } on ApiException catch (e) {
      errorCode = e.code;
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
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
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
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
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
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
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateCommitment(String id, Map<String, dynamic> data) async {
    _setLoading(true);
    try {
      await _api.patch('/commitments/$id', body: data);
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> simulateTask(Map<String, dynamic> payload) async {
    try {
      return await _api.post('/schedules/simulate', body: payload) as Map<String, dynamic>;
    } on ApiException catch (e) {
      errorCode = e.code;
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return null;
    } catch (_) {
      errorCode = 'INTERNAL_ERROR';
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return null;
    }
  }

  Future<bool> updateTask(String id, Map<String, dynamic> updates) async {
    _setLoading(true);
    try {
      await _taskRepo.updateTask(id, updates);
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> completeTask(String id, [int? actualMinutes, String? operationId]) async {
    _setLoading(true);
    try {
      await _taskRepo.completeTask(id, actualMinutes, operationId);
      lastApiException = null;
      isLastFailureAmbiguous = false;
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      lastApiException = e;
      isLastFailureAmbiguous = e.isAmbiguous;
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      isLastFailureAmbiguous = true;
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> reopenTask(String id) async {
    _setLoading(true);
    try {
      await _taskRepo.reopenTask(id);
      lastApiException = null;
      isLastFailureAmbiguous = false;
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      lastApiException = e;
      isLastFailureAmbiguous = e.isAmbiguous;
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      isLastFailureAmbiguous = true;
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recordTaskProgress(
    String id, {
    int? completedMinutes,
    int? additionalMinutes,
    int? actualMinutes,
    int? remainingMinutes,
    int? newEstimateMinutes,
    String? status,
    String? operationId,
  }) async {
    _setLoading(true);
    try {
      await _taskRepo.recordProgress(
        id,
        completedMinutes: completedMinutes,
        additionalMinutes: additionalMinutes,
        actualMinutes: actualMinutes,
        remainingMinutes: remainingMinutes,
        newEstimateMinutes: newEstimateMinutes,
        status: status,
        operationId: operationId,
      );
      lastApiException = null;
      isLastFailureAmbiguous = false;
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      lastApiException = e;
      isLastFailureAmbiguous = e.isAmbiguous;
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      isLastFailureAmbiguous = true;
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> splitTask(String id, int parts) async {
    _setLoading(true);
    try {
      await _api.post('/tasks/$id/split', body: {'parts': parts});
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (_) {
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
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> importSyllabusPdf(Uint8List bytes) async {
    _setLoading(true);
    try {
      return await _api.postBinary('/imports/syllabus', bytes, 'application/pdf');
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return null;
    } catch (_) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> confirmSyllabusTasks(String jobId, List<Map<String, dynamic>> candidates) async {
    _setLoading(true);
    try {
      await _api.post('/imports/syllabus/$jobId/confirm', body: {
        'candidates': candidates
      });
      await fetchDashboardData();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (_) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<Map<String, dynamic>?> importIcs(String icsData) async {
    _setLoading(true);
    try {
      final res = await _api.postText('/imports/calendar/ics', icsData, contentType: 'text/calendar');
      await fetchDashboardData();
      return res;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return null;
    } catch (_) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return null;
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
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<List<Map<String, dynamic>>> getRoutines() async {
    try {
      final res = await _api.get('/routines') as Map<String, dynamic>;
      final list = (res['routines'] as List? ?? []).cast<Map<String, dynamic>>();
      return list;
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateRoutines(List<Map<String, dynamic>> routines) async {
    _setLoading(true);
    try {
      await _api.put('/routines', body: {'routines': routines});
      await generateSchedule();
      return true;
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return false;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<ReplanSummary?> reschedule() async {
    if (isLoading || currentSchedule == null) return null;
    _setLoading(true);
    try {
      // Capture the current schedule as previous before we fetch the new one
      previousSchedule = currentSchedule;
      final newVersion = await _scheduleRepo.reschedule(currentSchedule!.id);
      await fetchDashboardData();

      final deferredLogs = newVersion.decisionLogs.where((d) => d.decisionType == DecisionType.deferred).toList();
      final deferredTitles = <String>[];
      for (final log in deferredLogs) {
        final task = activeTasks.cast<Task?>().firstWhere(
          (t) => t != null && t.id == log.taskId,
          orElse: () => null,
        );
        deferredTitles.add(task?.title ?? 'Task');
      }

      final taskBlocks = newVersion.blocks.where((b) => b.type == 'TASK' && b.taskId != null).toList();
      final uniqueScheduledTaskIds = taskBlocks.map((b) => b.taskId!).toSet();
      final totalMinutes = taskBlocks.fold<int>(0, (sum, b) => sum + b.durationMinutes);

      final String message;
      if (deferredLogs.isNotEmpty) {
        final titlesStr = deferredTitles.take(2).join(', ');
        final moreCount = deferredTitles.length > 2 ? ' +${deferredTitles.length - 2} more' : '';
        message = 'Re-planned: $totalMinutes min scheduled. ${deferredLogs.length} task(s) deferred ($titlesStr$moreCount) due to capacity.';
      } else {
        message = 'Schedule updated: $totalMinutes min planned across ${uniqueScheduledTaskIds.length} tasks.';
      }

      return ReplanSummary(
        scheduledTaskCount: uniqueScheduledTaskIds.length,
        totalScheduledMinutes: totalMinutes,
        deferredTaskCount: deferredLogs.length,
        deferredTaskTitles: deferredTitles,
        hasDeferred: deferredLogs.isNotEmpty,
        userMessage: message,
      );
    } on ApiException catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage(e.code, e.message);
      return null;
    } catch (e) {
      errorMessage = ApiErrorMapper.getUserFacingMessage('INTERNAL_ERROR');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void clearChangeSummary() {
    previousSchedule = null;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    selectedDate = DateTime(date.year, date.month, date.day);
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
