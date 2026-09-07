enum CommitmentType { class_, lab, exam, personal, custom }

class FixedCommitment {
  final String id;
  final String title;
  final DateTime startTime;
  final DateTime endTime;
  final CommitmentType type;
  final bool isActive;

  FixedCommitment({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.type = CommitmentType.custom,
    this.isActive = true,
  });

  factory FixedCommitment.fromJson(Map<String, dynamic> json) {
    return FixedCommitment(
      id: json['id'] as String,
      title: json['title'] as String,
      startTime: DateTime.parse(json['startTime'] as String).toLocal(),
      endTime: DateTime.parse(json['endTime'] as String).toLocal(),
      type: CommitmentType.values.firstWhere(
        (e) {
          final enumName = e.name == 'class_' ? 'CLASS' : e.name.toUpperCase();
          return enumName == (json['type'] as String?)?.toUpperCase();
        },
        orElse: () => CommitmentType.custom,
      ),
      isActive: json['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'startTime': startTime.toUtc().toIso8601String(),
      'endTime': endTime.toUtc().toIso8601String(),
      'type': type == CommitmentType.class_ ? 'CLASS' : type.name.toUpperCase(),
      'isActive': isActive,
    };
  }
}
