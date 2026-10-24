import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents an in-flight or ambiguous task progress submission.
/// Contains only identifiers, action type, and workload minute integers.
/// Never stores authentication tokens, credentials, or user-sensitive notes.
class PendingProgressOperation {
  final String taskId;
  final String operationId;
  final String action; // 'COMPLETE' or 'PROGRESS'
  final int? actualMinutes;
  final int? additionalMinutes;
  final int? remainingMinutes;
  final int? newEstimateMinutes;
  final String? status;
  final int timestamp;

  const PendingProgressOperation({
    required this.taskId,
    required this.operationId,
    required this.action,
    this.actualMinutes,
    this.additionalMinutes,
    this.remainingMinutes,
    this.newEstimateMinutes,
    this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'taskId': taskId,
    'operationId': operationId,
    'action': action,
    if (actualMinutes != null) 'actualMinutes': actualMinutes,
    if (additionalMinutes != null) 'additionalMinutes': additionalMinutes,
    if (remainingMinutes != null) 'remainingMinutes': remainingMinutes,
    if (newEstimateMinutes != null) 'newEstimateMinutes': newEstimateMinutes,
    if (status != null) 'status': status,
    'timestamp': timestamp,
  };

  factory PendingProgressOperation.fromJson(Map<String, dynamic> json) =>
      PendingProgressOperation(
        taskId: json['taskId'] as String,
        operationId: json['operationId'] as String,
        action: json['action'] as String,
        actualMinutes: json['actualMinutes'] as int?,
        additionalMinutes: json['additionalMinutes'] as int?,
        remainingMinutes: json['remainingMinutes'] as int?,
        newEstimateMinutes: json['newEstimateMinutes'] as int?,
        status: json['status'] as String?,
        timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      );
}

class PendingOperationManager {
  static const String _keyPrefix = 'pending_progress_op_';

  static String _key(String taskId) => '$_keyPrefix$taskId';

  /// Saves a pending operation to SharedPreferences.
  static Future<void> savePendingOperation(PendingProgressOperation op) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(op.taskId), jsonEncode(op.toJson()));
  }

  /// Retrieves any saved ambiguous/pending operation for this task.
  static Future<PendingProgressOperation?> getPendingOperation(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(taskId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return PendingProgressOperation.fromJson(decoded);
    } catch (_) {
      await clearPendingOperation(taskId);
      return null;
    }
  }

  /// Clears the pending operation for this task after definitive resolution.
  static Future<void> clearPendingOperation(String taskId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(taskId));
  }
}
