class DashboardMetrics {
  final TodayMetrics today;
  final TaskMetrics tasks;
  final List<Map<String, dynamic>> upcomingBlocks;
  final List<ExamCountdown> examCountdowns;
  final String? scheduleVersionId;
  final DateTime? scheduleGeneratedAt;

  const DashboardMetrics({
    required this.today,
    required this.tasks,
    required this.upcomingBlocks,
    required this.examCountdowns,
    this.scheduleVersionId,
    this.scheduleGeneratedAt,
  });

  factory DashboardMetrics.fromJson(Map<String, dynamic> json) => DashboardMetrics(
    today: TodayMetrics.fromJson(json['today'] as Map<String, dynamic>),
    tasks: TaskMetrics.fromJson(json['tasks'] as Map<String, dynamic>),
    upcomingBlocks: (json['upcomingBlocks'] as List<dynamic>? ?? [])
        .cast<Map<String, dynamic>>(),
    examCountdowns: (json['examCountdowns'] as List<dynamic>? ?? [])
        .map((e) => ExamCountdown.fromJson(e as Map<String, dynamic>))
        .toList(),
    scheduleVersionId: json['scheduleVersionId'] as String?,
    scheduleGeneratedAt: json['scheduleGeneratedAt'] != null
        ? DateTime.parse(json['scheduleGeneratedAt'] as String)
        : null,
  );
}

class TodayMetrics {
  final int plannedMinutes;
  final int completedMinutes;
  final int remainingMinutes;
  final int focusMinutes;
  final int taskBlockCount;
  final int completedTaskBlockCount;

  const TodayMetrics({
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.remainingMinutes,
    required this.focusMinutes,
    required this.taskBlockCount,
    required this.completedTaskBlockCount,
  });

  factory TodayMetrics.fromJson(Map<String, dynamic> json) => TodayMetrics(
    plannedMinutes: json['plannedMinutes'] as int? ?? 0,
    completedMinutes: json['completedMinutes'] as int? ?? 0,
    remainingMinutes: json['remainingMinutes'] as int? ?? 0,
    focusMinutes: json['focusMinutes'] as int? ?? 0,
    taskBlockCount: json['taskBlockCount'] as int? ?? 0,
    completedTaskBlockCount: json['completedTaskBlockCount'] as int? ?? 0,
  );

  String formatMinutes(int mins) {
    if (mins == 0) return '0m';
    final h = mins ~/ 60;
    final m = mins % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  String get plannedStr => formatMinutes(plannedMinutes);
  String get completedStr => formatMinutes(completedMinutes);
  String get remainingStr => formatMinutes(remainingMinutes);
  String get focusStr => formatMinutes(focusMinutes);

  double get progressPercent => plannedMinutes > 0
      ? (completedMinutes / plannedMinutes).clamp(0.0, 1.0)
      : 0.0;
}

class TaskMetrics {
  final int total;
  final int completed;
  final int pending;
  final int overdue;
  final int dueToday;
  final int dueNext3Days;
  final int deferred;
  final int completionRate;
  final int totalRemainingMinutes;

  const TaskMetrics({
    required this.total,
    required this.completed,
    required this.pending,
    required this.overdue,
    required this.dueToday,
    required this.dueNext3Days,
    required this.deferred,
    required this.completionRate,
    required this.totalRemainingMinutes,
  });

  factory TaskMetrics.fromJson(Map<String, dynamic> json) => TaskMetrics(
    total: json['total'] as int? ?? 0,
    completed: json['completed'] as int? ?? 0,
    pending: json['pending'] as int? ?? 0,
    overdue: json['overdue'] as int? ?? 0,
    dueToday: json['dueToday'] as int? ?? 0,
    dueNext3Days: json['dueNext3Days'] as int? ?? 0,
    deferred: json['deferred'] as int? ?? 0,
    completionRate: json['completionRate'] as int? ?? 0,
    totalRemainingMinutes: json['totalRemainingMinutes'] as int? ?? 0,
  );
}

class ExamCountdown {
  final String id;
  final String title;
  final DateTime examDate;
  final int daysLeft;
  final int totalTopics;
  final int completedTopics;
  final int coveragePercent;
  final int remainingMinutes;

  const ExamCountdown({
    required this.id,
    required this.title,
    required this.examDate,
    required this.daysLeft,
    required this.totalTopics,
    required this.completedTopics,
    required this.coveragePercent,
    required this.remainingMinutes,
  });

  factory ExamCountdown.fromJson(Map<String, dynamic> json) => ExamCountdown(
    id: json['id'] as String,
    title: json['title'] as String,
    examDate: DateTime.parse(json['examDate'] as String),
    daysLeft: json['daysLeft'] as int? ?? 0,
    totalTopics: json['totalTopics'] as int? ?? 0,
    completedTopics: json['completedTopics'] as int? ?? 0,
    coveragePercent: json['coveragePercent'] as int? ?? 0,
    remainingMinutes: json['remainingMinutes'] as int? ?? 0,
  );
}
