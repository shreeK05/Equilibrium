class UserProfile {
  final String id;
  final String email;
  final String? name;
  final String? college;
  final String? degree;
  final String? branch;
  final String? semester;
  final String themePreference; // "light", "dark", "system"
  final String timezone;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.college,
    this.degree,
    this.branch,
    this.semester,
    required this.themePreference,
    required this.timezone,
    required this.createdAt,
  });

  String get displayName => name?.isNotEmpty == true ? name! : email.split('@').first;
  String get initials {
    if (name != null && name!.isNotEmpty) {
      final parts = name!.trim().split(' ');
      if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
      return parts.first[0].toUpperCase();
    }
    return email[0].toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    email: json['email'] as String,
    name: json['name'] as String?,
    college: json['college'] as String?,
    degree: json['degree'] as String?,
    branch: json['branch'] as String?,
    semester: json['semester'] as String?,
    themePreference: json['themePreference'] as String? ?? 'system',
    timezone: json['timezone'] as String? ?? 'UTC',
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    if (name != null) 'name': name,
    if (college != null) 'college': college,
    if (degree != null) 'degree': degree,
    if (branch != null) 'branch': branch,
    if (semester != null) 'semester': semester,
    'themePreference': themePreference,
    'timezone': timezone,
    'createdAt': createdAt.toIso8601String(),
  };

  UserProfile copyWith({
    String? name,
    String? college,
    String? degree,
    String? branch,
    String? semester,
    String? themePreference,
    String? timezone,
  }) => UserProfile(
    id: id,
    email: email,
    name: name ?? this.name,
    college: college ?? this.college,
    degree: degree ?? this.degree,
    branch: branch ?? this.branch,
    semester: semester ?? this.semester,
    themePreference: themePreference ?? this.themePreference,
    timezone: timezone ?? this.timezone,
    createdAt: createdAt,
  );
}
