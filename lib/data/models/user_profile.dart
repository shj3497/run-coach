/// 사용자 프로필 모델
/// DB 테이블: user_profiles (auth.users와 1:1)
class UserProfile {
  final String id;
  final String nickname;
  final int? birthYear;
  final String? gender;
  final double? heightCm;
  final double? weightKg;
  final String? runningExperience;
  final String? preferredDistance;
  final int? weeklyAvailableDays;
  final String timezone;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.nickname,
    this.birthYear,
    this.gender,
    this.heightCm,
    this.weightKg,
    this.runningExperience,
    this.preferredDistance,
    this.weeklyAvailableDays,
    this.timezone = 'Asia/Seoul',
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        nickname: json['nickname'] as String,
        birthYear: json['birth_year'] as int?,
        gender: json['gender'] as String?,
        heightCm: (json['height_cm'] as num?)?.toDouble(),
        weightKg: (json['weight_kg'] as num?)?.toDouble(),
        runningExperience: json['running_experience'] as String?,
        preferredDistance: json['preferred_distance'] as String?,
        weeklyAvailableDays: json['weekly_available_days'] as int?,
        timezone: json['timezone'] as String? ?? 'Asia/Seoul',
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'nickname': nickname,
        'birth_year': birthYear,
        'gender': gender,
        'height_cm': heightCm,
        'weight_kg': weightKg,
        'running_experience': runningExperience,
        'preferred_distance': preferredDistance,
        'weekly_available_days': weeklyAvailableDays,
        'timezone': timezone,
      };

  UserProfile copyWith({
    String? id,
    String? nickname,
    int? birthYear,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? runningExperience,
    String? preferredDistance,
    int? weeklyAvailableDays,
    String? timezone,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      UserProfile(
        id: id ?? this.id,
        nickname: nickname ?? this.nickname,
        birthYear: birthYear ?? this.birthYear,
        gender: gender ?? this.gender,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        runningExperience: runningExperience ?? this.runningExperience,
        preferredDistance: preferredDistance ?? this.preferredDistance,
        weeklyAvailableDays: weeklyAvailableDays ?? this.weeklyAvailableDays,
        timezone: timezone ?? this.timezone,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
