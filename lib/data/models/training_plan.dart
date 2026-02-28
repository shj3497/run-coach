/// 훈련 플랜 모델
/// DB 테이블: training_plans
class TrainingPlan {
  final String id;
  final String userId;
  final String planName;
  final String status;
  final String? goalRaceName;
  final DateTime? goalRaceDate;
  final double goalDistanceKm;
  final int? goalTimeSeconds;
  final double? vdotScore;
  final int totalWeeks;
  final DateTime startDate;
  final DateTime endDate;
  final int trainingDaysPerWeek;
  final Map<String, dynamic>? paceZones;
  final Map<String, dynamic>? llmContextSnapshot;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TrainingPlan({
    required this.id,
    required this.userId,
    required this.planName,
    this.status = 'upcoming',
    this.goalRaceName,
    this.goalRaceDate,
    required this.goalDistanceKm,
    this.goalTimeSeconds,
    this.vdotScore,
    required this.totalWeeks,
    required this.startDate,
    required this.endDate,
    required this.trainingDaysPerWeek,
    this.paceZones,
    this.llmContextSnapshot,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TrainingPlan.fromJson(Map<String, dynamic> json) => TrainingPlan(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        planName: json['plan_name'] as String,
        status: json['status'] as String? ?? 'upcoming',
        goalRaceName: json['goal_race_name'] as String?,
        goalRaceDate: json['goal_race_date'] != null
            ? DateTime.parse(json['goal_race_date'] as String)
            : null,
        goalDistanceKm: (json['goal_distance_km'] as num).toDouble(),
        goalTimeSeconds: json['goal_time_seconds'] as int?,
        vdotScore: (json['vdot_score'] as num?)?.toDouble(),
        totalWeeks: json['total_weeks'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        trainingDaysPerWeek: json['training_days_per_week'] as int,
        paceZones: json['pace_zones'] as Map<String, dynamic>?,
        llmContextSnapshot:
            json['llm_context_snapshot'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'plan_name': planName,
        'status': status,
        'goal_race_name': goalRaceName,
        'goal_race_date': goalRaceDate?.toIso8601String().substring(0, 10),
        'goal_distance_km': goalDistanceKm,
        'goal_time_seconds': goalTimeSeconds,
        'vdot_score': vdotScore,
        'total_weeks': totalWeeks,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'training_days_per_week': trainingDaysPerWeek,
        'pace_zones': paceZones,
        'llm_context_snapshot': llmContextSnapshot,
      };
}
