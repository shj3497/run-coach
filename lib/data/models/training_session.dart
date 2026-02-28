/// 일별 훈련 세션 모델
/// DB 테이블: training_sessions
class TrainingSession {
  final String id;
  final String weekId;
  final String planId;
  final DateTime sessionDate;
  final int dayOfWeek;
  final String sessionType;
  final String title;
  final String? description;
  final double? targetDistanceKm;
  final int? targetDurationMinutes;
  final String? targetPace;
  final Map<String, dynamic>? workoutDetail;
  final String status;
  final DateTime? completedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingSession({
    required this.id,
    required this.weekId,
    required this.planId,
    required this.sessionDate,
    required this.dayOfWeek,
    required this.sessionType,
    required this.title,
    this.description,
    this.targetDistanceKm,
    this.targetDurationMinutes,
    this.targetPace,
    this.workoutDetail,
    this.status = 'pending',
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingSession.fromJson(Map<String, dynamic> json) =>
      TrainingSession(
        id: json['id'] as String,
        weekId: json['week_id'] as String,
        planId: json['plan_id'] as String,
        sessionDate: DateTime.parse(json['session_date'] as String),
        dayOfWeek: json['day_of_week'] as int,
        sessionType: json['session_type'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        targetDistanceKm: (json['target_distance_km'] as num?)?.toDouble(),
        targetDurationMinutes: json['target_duration_minutes'] as int?,
        targetPace: json['target_pace'] as String?,
        workoutDetail: json['workout_detail'] as Map<String, dynamic>?,
        status: json['status'] as String? ?? 'pending',
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'week_id': weekId,
        'plan_id': planId,
        'session_date': sessionDate.toIso8601String().substring(0, 10),
        'day_of_week': dayOfWeek,
        'session_type': sessionType,
        'title': title,
        'description': description,
        'target_distance_km': targetDistanceKm,
        'target_duration_minutes': targetDurationMinutes,
        'target_pace': targetPace,
        'workout_detail': workoutDetail,
        'status': status,
        'completed_at': completedAt?.toIso8601String(),
      };
}
