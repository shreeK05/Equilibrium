enum CommitmentType { class_, lab, exam, personal, custom, routine }

class FixedCommitment {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final CommitmentType type;
  final bool isActive;
  final String? recurrence;
  final String? daysOfWeek;
  final String flexibility;
  final String? color;

  FixedCommitment({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.type = CommitmentType.custom,
    this.isActive = true,
    this.recurrence,
    this.daysOfWeek,
    this.flexibility = 'FIXED',
    this.color,
  });

  factory FixedCommitment.fromJson(Map<String, dynamic> json) {
    return FixedCommitment(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String).toLocal(),
      endTime: DateTime.parse(json['endTime'] as String).toLocal(),
      type: CommitmentType.values.firstWhere(
        (e) {
          final enumName = e == CommitmentType.class_ ? 'CLASS' : e.toString().split('.').last.toUpperCase();
          return enumName == (json['type'] as String?)?.toUpperCase();
        },
        orElse: () => CommitmentType.custom,
      ),
      isActive: json['isActive'] as bool? ?? true,
      recurrence: json['recurrence'] as String?,
      daysOfWeek: json['daysOfWeek'] as String?,
      flexibility: json['flexibility'] as String? ?? 'FIXED',
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'type': type == CommitmentType.class_ ? 'CLASS' : type.toString().split('.').last.toUpperCase(),
      'isActive': isActive,
      if (recurrence != null) 'recurrence': recurrence,
      if (daysOfWeek != null) 'daysOfWeek': daysOfWeek,
      'flexibility': flexibility,
      if (color != null) 'color': color,
    };
  }
}
