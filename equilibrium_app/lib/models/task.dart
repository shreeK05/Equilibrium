enum TaskStatus {
  pending,
  inProgress,
  scheduled,
  partiallyScheduled,
  deferred,
  completed,
  archived,
  overdue,
}
enum CognitiveLoad { low, medium, high }

class Task {
  final String id;
  final String title;
  final int estimateMinutes;
  final int completedMinutes;
  final int remainingMinutes;
  final DateTime deadline;
  final double academicWeight;
  final double teamImpactWeight;
  final CognitiveLoad cognitiveLoad;
  final TaskStatus status;

  Task({
    required this.id,
    required this.title,
    required this.estimateMinutes,
    required this.completedMinutes,
    required this.remainingMinutes,
    required this.deadline,
    this.academicWeight = 0.0,
    this.teamImpactWeight = 0.0,
    this.cognitiveLoad = CognitiveLoad.medium,
    this.status = TaskStatus.pending,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      estimateMinutes: json['estimateMinutes'] as int,
      completedMinutes: json['completedMinutes'] as int? ?? 0,
      remainingMinutes: json['remainingMinutes'] as int? ?? json['estimateMinutes'] as int,
      deadline: DateTime.parse(json['deadline'] as String),
      academicWeight: (json['academicWeight'] as num?)?.toDouble() ?? 0.0,
      teamImpactWeight: (json['teamImpactWeight'] as num?)?.toDouble() ?? 0.0,
      cognitiveLoad: CognitiveLoad.values.firstWhere(
        (e) => e.name.toUpperCase() == (json['cognitiveLoad'] as String?)?.toUpperCase(),
        orElse: () => CognitiveLoad.medium,
      ),
      status: _parseStatus(json['status'] as String?),
    );
  }

  static TaskStatus _parseStatus(String? rawStatus) {
    switch (rawStatus?.toUpperCase()) {
      case 'PENDING':
        return TaskStatus.pending;
      case 'IN_PROGRESS':
        return TaskStatus.inProgress;
      case 'SCHEDULED':
        return TaskStatus.scheduled;
      case 'PARTIALLY_SCHEDULED':
        return TaskStatus.partiallyScheduled;
      case 'DEFERRED':
        return TaskStatus.deferred;
      case 'COMPLETED':
        return TaskStatus.completed;
      case 'ARCHIVED':
        return TaskStatus.archived;
      case 'OVERDUE':
        return TaskStatus.overdue;
      default:
        return TaskStatus.pending;
    }
  }
}