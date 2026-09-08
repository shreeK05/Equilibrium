class ExamTopic {
  final String id;
  final String examId;
  final String title;
  final int estimateMinutes;
  final double confidence;
  final String topicType; // REVISION, PYQ, MOCK_TEST, LEARNING, WEAK_TOPIC
  final bool isCompleted;
  final String? linkedTaskId;
  final DateTime createdAt;

  const ExamTopic({
    required this.id,
    required this.examId,
    required this.title,
    required this.estimateMinutes,
    required this.confidence,
    required this.topicType,
    required this.isCompleted,
    this.linkedTaskId,
    required this.createdAt,
  });

  factory ExamTopic.fromJson(Map<String, dynamic> json) => ExamTopic(
    id: json['id'] as String,
    examId: json['examId'] as String,
    title: json['title'] as String,
    estimateMinutes: json['estimateMinutes'] as int? ?? 60,
    confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    topicType: json['topicType'] as String? ?? 'REVISION',
    isCompleted: json['isCompleted'] as bool? ?? false,
    linkedTaskId: json['linkedTaskId'] as String?,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  String get topicTypeLabel {
    switch (topicType) {
      case 'PYQ': return 'PYQ Practice';
      case 'MOCK_TEST': return 'Mock Test';
      case 'LEARNING': return 'Learning';
      case 'WEAK_TOPIC': return 'Weak Topic';
      default: return 'Revision';
    }
  }
}

class Exam {
  final String id;
  final String userId;
  final String? subjectId;
  final String? subjectName;
  final String? subjectColor;
  final String title;
  final DateTime examDate;
  final String? venue;
  final List<ExamTopic> topics;
  final DateTime createdAt;

  const Exam({
    required this.id,
    required this.userId,
    this.subjectId,
    this.subjectName,
    this.subjectColor,
    required this.title,
    required this.examDate,
    this.venue,
    required this.topics,
    required this.createdAt,
  });

  int get daysUntilExam {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final examDay = DateTime(examDate.year, examDate.month, examDate.day);
    return examDay.difference(today).inDays;
  }

  bool get isUpcoming => examDate.isAfter(DateTime.now());
  bool get isPast => examDate.isBefore(DateTime.now());

  int get completedTopics => topics.where((t) => t.isCompleted).length;
  int get totalTopics => topics.length;
  int get coveragePercent => totalTopics > 0 ? ((completedTopics / totalTopics) * 100).round() : 0;
  int get remainingMinutes => topics.where((t) => !t.isCompleted).fold(0, (s, t) => s + t.estimateMinutes);
  int get totalMinutes => topics.fold(0, (s, t) => s + t.estimateMinutes);

  factory Exam.fromJson(Map<String, dynamic> json) {
    final subjectJson = json['subject'] as Map<String, dynamic>?;
    return Exam(
      id: json['id'] as String,
      userId: json['userId'] as String,
      subjectId: json['subjectId'] as String?,
      subjectName: subjectJson?['name'] as String?,
      subjectColor: subjectJson?['color'] as String?,
      title: json['title'] as String,
      examDate: DateTime.parse(json['examDate'] as String),
      venue: json['venue'] as String?,
      topics: (json['topics'] as List<dynamic>? ?? [])
          .map((t) => ExamTopic.fromJson(t as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class Subject {
  final String id;
  final String userId;
  final String name;
  final String? color;
  final int taskCount;
  final int examCount;

  const Subject({
    required this.id,
    required this.userId,
    required this.name,
    this.color,
    this.taskCount = 0,
    this.examCount = 0,
  });

  factory Subject.fromJson(Map<String, dynamic> json) => Subject(
    id: json['id'] as String,
    userId: json['userId'] as String,
    name: json['name'] as String,
    color: json['color'] as String?,
    taskCount: (json['_count'] as Map<String, dynamic>?)?['tasks'] as int? ?? 0,
    examCount: (json['_count'] as Map<String, dynamic>?)?['exams'] as int? ?? 0,
  );
}
