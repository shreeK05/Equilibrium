class FocusSession {
  final String id;
  final String userId;
  final String? taskId;
  final String? taskTitle;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int elapsedSeconds;
  final String status; // RUNNING, PAUSED, COMPLETED, DISCARDED
  final String? notes;
  final DateTime createdAt;
  final int totalPausedMs;
  final DateTime? pausedAt;

  const FocusSession({
    required this.id,
    required this.userId,
    this.taskId,
    this.taskTitle,
    required this.startedAt,
    this.endedAt,
    required this.elapsedSeconds,
    required this.status,
    this.notes,
    required this.createdAt,
    required this.totalPausedMs,
    this.pausedAt,
  });

  bool get isRunning => status == 'RUNNING';
  bool get isPaused => status == 'PAUSED';
  bool get isCompleted => status == 'COMPLETED';
  bool get isActive => status == 'RUNNING' || status == 'PAUSED';

  /// Calculate current elapsed seconds in real-time (for display while RUNNING)
  int get currentElapsedSeconds {
    if (status == 'RUNNING') {
      final now = DateTime.now();
      final additionalMs = now.difference(startedAt).inMilliseconds - totalPausedMs;
      return elapsedSeconds + (additionalMs / 1000).floor();
    }
    return elapsedSeconds;
  }

  String get formattedDuration {
    final secs = currentElapsedSeconds;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  factory FocusSession.fromJson(Map<String, dynamic> json) => FocusSession(
    id: json['id'] as String,
    userId: json['userId'] as String,
    taskId: json['taskId'] as String?,
    taskTitle: (json['task'] as Map<String, dynamic>?)?['title'] as String?,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt'] as String) : null,
    elapsedSeconds: json['elapsedSeconds'] as int? ?? 0,
    status: json['status'] as String,
    notes: json['notes'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
    totalPausedMs: json['totalPausedMs'] as int? ?? 0,
    pausedAt: json['pausedAt'] != null ? DateTime.parse(json['pausedAt'] as String) : null,
  );
}
