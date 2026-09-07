import 'dart:convert';

class DecisionLog {
  final String id;
  final String versionId;
  final String taskId;
  final DecisionType decisionType;
  final double priorityScore;
  final Map<String, dynamic> priorityComponents;
  final DecisionReason reasonCode;
  final String humanReadable;

  DecisionLog({
    required this.id,
    required this.versionId,
    required this.taskId,
    required this.decisionType,
    required this.priorityScore,
    required this.priorityComponents,
    required this.reasonCode,
    required this.humanReadable,
  });

  factory DecisionLog.fromJson(Map<String, dynamic> json) {
    return DecisionLog(
      id: json['id'] as String,
      versionId: json['versionId'] as String,
      taskId: json['taskId'] as String,
      decisionType: _parseDecisionType(json['decisionType'] as String?),
      priorityScore: (json['priorityScore'] as num?)?.toDouble() ?? 0.0,
      priorityComponents: _parseComponents(json),
      reasonCode: _parseReasonCode(json['reasonCode'] as String?),
      humanReadable: json['humanReadable'] as String? ?? 'Unknown',
    );
  }

  static Map<String, dynamic> _parseComponents(Map<String, dynamic> json) {
    final value = json['priorityComponents'];
    if (value is Map<String, dynamic>) return value;
    final raw = json['priorityComponentsJson'];
    if (raw is String) {
      try {
        final parsed = jsonDecode(raw);
        if (parsed is Map) return Map<String, dynamic>.from(parsed);
      } catch (_) {}
    }
    return {};
  }

  static DecisionType _parseDecisionType(String? value) {
    switch (value) {
      case 'FULLY_SCHEDULED': return DecisionType.fullyScheduled;
      case 'PARTIALLY_SCHEDULED': return DecisionType.partiallyScheduled;
      case 'DEFERRED': return DecisionType.deferred;
      default: return DecisionType.unknown;
    }
  }

  static DecisionReason _parseReasonCode(String? value) {
    switch (value) {
      case 'SUCCESS': return DecisionReason.success;
      case 'FRAGMENTED_CAPACITY': return DecisionReason.fragmentedCapacity;
      case 'NO_AVAILABLE_SLOTS': return DecisionReason.noAvailableSlots;
      case 'CAPACITY_EXCEEDED': return DecisionReason.capacityExceeded;
      default: return DecisionReason.other;
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'versionId': versionId,
    'taskId': taskId,
    'decisionType': _decisionTypeName(decisionType),
    'priorityScore': priorityScore,
    'priorityComponents': priorityComponents,
    'reasonCode': _reasonCodeName(reasonCode),
    'humanReadable': humanReadable,
  };

  static String _decisionTypeName(DecisionType value) {
    switch (value) {
      case DecisionType.fullyScheduled: return 'FULLY_SCHEDULED';
      case DecisionType.partiallyScheduled: return 'PARTIALLY_SCHEDULED';
      case DecisionType.deferred: return 'DEFERRED';
      case DecisionType.unknown: return 'UNKNOWN';
    }
  }

  static String _reasonCodeName(DecisionReason value) {
    switch (value) {
      case DecisionReason.success: return 'SUCCESS';
      case DecisionReason.fragmentedCapacity: return 'FRAGMENTED_CAPACITY';
      case DecisionReason.noAvailableSlots: return 'NO_AVAILABLE_SLOTS';
      case DecisionReason.capacityExceeded: return 'CAPACITY_EXCEEDED';
      case DecisionReason.other: return 'OTHER';
    }
  }
}

enum DecisionType {
  fullyScheduled,
  partiallyScheduled,
  deferred,
  unknown,
}

enum DecisionReason {
  success,
  fragmentedCapacity,
  noAvailableSlots,
  capacityExceeded,
  other,
}
