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
      isLocked: json['isLocked'] as bool? ?? false,
      // Backend uses 'blockType' field
      type: (json['blockType'] as String?) ?? (json['type'] as String?) ?? 'TASK',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'versionId': versionId,
    'taskId': taskId,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMinutes': durationMinutes,
    'isLocked': isLocked,
    'blockType': type,
  };
}

class ScheduleVersion {
  final String id;
  final String triggerType; // 'MANUAL' or 'DISRUPTION'
  final String? previousVersionId;
  final DateTime generatedAt;
  final int capacityMinutes;
  final List<ScheduleBlock> blocks;
  final List<DecisionLog> decisionLogs;

  ScheduleVersion({
    required this.id,
    required this.triggerType,
    required this.generatedAt,
    required this.capacityMinutes,
    required this.blocks,
    this.previousVersionId,
    this.decisionLogs = const [],
  });

  factory ScheduleVersion.fromJson(Map<String, dynamic> json) {
    return ScheduleVersion(
      id: json['id'] as String,
      triggerType: json['triggerType'] as String? ?? 'MANUAL',
      previousVersionId: json['previousVersionId'] as String?,
      generatedAt: DateTime.tryParse(json['generatedAt'] as String? ?? '') ?? DateTime.now(),
      capacityMinutes: json['capacityMinutes'] as int? ?? 0,
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'triggerType': triggerType,
    'previousVersionId': previousVersionId,
    'generatedAt': generatedAt.toIso8601String(),
    'capacityMinutes': capacityMinutes,
    'blocks': blocks.map((block) => block.toJson()).toList(),
    'decisionLogs': decisionLogs.map((log) => log.toJson()).toList(),
  };
}
