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
      priorityComponents: json['priorityComponents'] as Map<String, dynamic>? ?? {},
      reasonCode: _parseReasonCode(json['reasonCode'] as String?),
      humanReadable: json['humanReadable'] as String? ?? 'Unknown',
    );
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
