enum TaskStatus {
  pending,
  inProgress,
  partiallyCompleted,
  completed,
  archived,
  deferred,
  overdue,
}

enum CognitiveLoad { low, medium, high }
enum DeadlineType { hard, flexible }

class Task {
  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? category;
  final String? subjectId;
  final String? subjectName;
  final int estimateMinutes;
  final int completedMinutes;
  final int? dailyTargetMinutes;
  final DateTime deadline;
  final DeadlineType deadlineType;
  final double academicWeight;
  final double teamImpactWeight;
  final CognitiveLoad cognitiveLoad;
  final TaskStatus status;
  final int deferralCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  Task({
    required this.id,
    required this.userId,
    required this.title,
    this.description,
    this.category,
    this.subjectId,
    this.subjectName,
    required this.estimateMinutes,
    required this.completedMinutes,
    this.dailyTargetMinutes,
    required this.deadline,
    this.deadlineType = DeadlineType.hard,
    this.academicWeight = 0.5,
    this.teamImpactWeight = 0.0,
    this.cognitiveLoad = CognitiveLoad.medium,
    this.status = TaskStatus.pending,
    this.deferralCount = 0,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get remainingMinutes => (estimateMinutes - completedMinutes).clamp(0, estimateMinutes);
  double get progressPercent => estimateMinutes > 0 ? (completedMinutes / estimateMinutes).clamp(0.0, 1.0) : 0.0;
  bool get isCompleted => status == TaskStatus.completed;
  bool get isOverdue => deadline.isBefore(DateTime.now()) && !isCompleted;
  bool get isDueToday {
    final now = DateTime.now();
    return deadline.year == now.year && deadline.month == now.month && deadline.day == now.day;
  }

  String get cognitiveLoadLabel {
    switch (cognitiveLoad) {
      case CognitiveLoad.high: return 'HIGH';
      case CognitiveLoad.low: return 'LOW';
      default: return 'MED';
    }
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    final subjectJson = json['subject'] as Map<String, dynamic>?;
    return Task(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      title: json['title'] as String,
      description: json['description'] as String?,
      category: json['category'] as String?,
      subjectId: json['subjectId'] as String?,
      subjectName: subjectJson?['name'] as String?,
      estimateMinutes: json['estimateMinutes'] as int,
      completedMinutes: json['completedMinutes'] as int? ?? 0,
      dailyTargetMinutes: json['dailyTargetMinutes'] as int?,
      deadline: DateTime.parse(json['deadline'] as String),
      deadlineType: (json['deadlineType'] as String?) == 'FLEXIBLE'
          ? DeadlineType.flexible
          : DeadlineType.hard,
      academicWeight: (json['academicWeight'] as num?)?.toDouble() ?? 0.5,
      teamImpactWeight: (json['teamImpactWeight'] as num?)?.toDouble() ?? 0.0,
      cognitiveLoad: CognitiveLoad.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['cognitiveLoad'] as String?)?.toUpperCase(),
        orElse: () => CognitiveLoad.medium,
      ),
      status: _parseStatus(json['status'] as String?),
      deferralCount: json['deferralCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      updatedAt: json['updatedAt'] != null ? DateTime.parse(json['updatedAt'] as String) : null,
    );
  }

  static TaskStatus _parseStatus(String? rawStatus) {
    switch (rawStatus?.toUpperCase()) {
      case 'IN_PROGRESS':
        return TaskStatus.inProgress;
      case 'PARTIALLY_COMPLETED':
        return TaskStatus.partiallyCompleted;
      case 'COMPLETED':
        return TaskStatus.completed;
      case 'ARCHIVED':
        return TaskStatus.archived;
      case 'DEFERRED':
        return TaskStatus.deferred;
      default:
        return TaskStatus.pending;
    }
  }

  Task copyWith({
    String? title,
    String? description,
    String? category,
    String? subjectId,
    int? estimateMinutes,
    int? completedMinutes,
    DateTime? deadline,
    DeadlineType? deadlineType,
    double? academicWeight,
    CognitiveLoad? cognitiveLoad,
    TaskStatus? status,
  }) => Task(
    id: id, userId: userId,
    title: title ?? this.title,
    description: description ?? this.description,
    category: category ?? this.category,
    subjectId: subjectId ?? this.subjectId,
    subjectName: subjectName,
    estimateMinutes: estimateMinutes ?? this.estimateMinutes,
    completedMinutes: completedMinutes ?? this.completedMinutes,
    deadline: deadline ?? this.deadline,
    deadlineType: deadlineType ?? this.deadlineType,
    academicWeight: academicWeight ?? this.academicWeight,
    teamImpactWeight: teamImpactWeight,
    cognitiveLoad: cognitiveLoad ?? this.cognitiveLoad,
    status: status ?? this.status,
    deferralCount: deferralCount,
    createdAt: createdAt,
    updatedAt: DateTime.now(),
  );
}