/// 훈련 주차 모델
/// DB 테이블: training_weeks
class TrainingWeek {
  final String id;
  final String planId;
  final int weekNumber;
  final DateTime startDate;
  final DateTime endDate;
  final String phase;
  final double? targetDistanceKm;
  final String? weeklySummary;
  final DateTime createdAt;

  const TrainingWeek({
    required this.id,
    required this.planId,
    required this.weekNumber,
    required this.startDate,
    required this.endDate,
    required this.phase,
    this.targetDistanceKm,
    this.weeklySummary,
    required this.createdAt,
  });

  factory TrainingWeek.fromJson(Map<String, dynamic> json) => TrainingWeek(
        id: json['id'] as String,
        planId: json['plan_id'] as String,
        weekNumber: json['week_number'] as int,
        startDate: DateTime.parse(json['start_date'] as String),
        endDate: DateTime.parse(json['end_date'] as String),
        phase: json['phase'] as String,
        targetDistanceKm: (json['target_distance_km'] as num?)?.toDouble(),
        weeklySummary: json['weekly_summary'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'plan_id': planId,
        'week_number': weekNumber,
        'start_date': startDate.toIso8601String().substring(0, 10),
        'end_date': endDate.toIso8601String().substring(0, 10),
        'phase': phase,
        'target_distance_km': targetDistanceKm,
        'weekly_summary': weeklySummary,
      };
}
