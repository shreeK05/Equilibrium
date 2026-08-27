import 'decision_log.dart';

class ScheduleBlock {
  final String id;
  final String versionId;
  final String? taskId;
  final DateTime startTime;
  final DateTime endTime;
  final int durationMinutes;
  final bool isLocked;
  final String type; // 'TASK', 'SLEEP', 'FIXED', 'BREAK', 'FREE'

  ScheduleBlock({
    required this.id,
    required this.versionId,
    this.taskId,
    required this.startTime,
    required this.endTime,
    required this.durationMinutes,
    required this.isLocked,
    required this.type,
  });

  factory ScheduleBlock.fromJson(Map<String, dynamic> json) {
    return ScheduleBlock(
      id: json['id'] as String,
      versionId: json['versionId'] as String,
      taskId: json['taskId'] as String?,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      durationMinutes: json['durationMinutes'] as int,
      isLocked: json['isLocked'] as bool,
      type: json['type'] as String? ?? 'TASK',
    );
  }
}

class ScheduleVersion {
  final String id;
  final DateTime horizonStart;
  final DateTime horizonEnd;
  final String triggerType; // 'MANUAL' or 'DISRUPTION'
  final String? previousVersionId;
  final List<ScheduleBlock> blocks;
  final List<DecisionLog> decisionLogs;

  ScheduleVersion({
    required this.id,
    required this.horizonStart,
    required this.horizonEnd,
    required this.triggerType,
    required this.blocks,
    this.previousVersionId,
    this.decisionLogs = const [],
  });

  factory ScheduleVersion.fromJson(Map<String, dynamic> json) {
    return ScheduleVersion(
      id: json['id'] as String,
      horizonStart: DateTime.parse(json['horizonStart'] as String),
      horizonEnd: DateTime.parse(json['horizonEnd'] as String),
      triggerType: json['triggerType'] as String,
      previousVersionId: json['previousVersionId'] as String?,
      blocks: (json['blocks'] as List<dynamic>?)
              ?.map((e) => ScheduleBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      decisionLogs: (json['decisionLogs'] as List<dynamic>?)
              ?.map((e) => DecisionLog.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
