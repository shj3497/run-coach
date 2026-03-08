/// 운동 기록 모델
/// DB 테이블: workout_logs
class WorkoutLog {
  final String id;
  final String userId;
  final String? sessionId;
  final String source;
  final String? externalId;
  final DateTime workoutDate;
  final DateTime startedAt;
  final DateTime endedAt;
  final double distanceKm;
  final int durationSeconds;
  final int? avgPaceSecondsPerKm;
  final int? avgHeartRate;
  final int? maxHeartRate;
  final int? totalCalories;
  final int? avgCadence;
  final double? totalElevationGainM;
  final List<dynamic>? splits;
  final List<dynamic>? heartRateData;
  final String? routePolyline;
  final double? weatherTempC;
  final int? weatherHumidity;
  final String? weatherCondition;
  final String? memo;
  final Map<String, dynamic>? weatherContext;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WorkoutLog({
    required this.id,
    required this.userId,
    this.sessionId,
    required this.source,
    this.externalId,
    required this.workoutDate,
    required this.startedAt,
    required this.endedAt,
    required this.distanceKm,
    required this.durationSeconds,
    this.avgPaceSecondsPerKm,
    this.avgHeartRate,
    this.maxHeartRate,
    this.totalCalories,
    this.avgCadence,
    this.totalElevationGainM,
    this.splits,
    this.heartRateData,
    this.routePolyline,
    this.weatherTempC,
    this.weatherHumidity,
    this.weatherCondition,
    this.memo,
    this.weatherContext,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WorkoutLog.fromJson(Map<String, dynamic> json) => WorkoutLog(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        sessionId: json['session_id'] as String?,
        source: json['source'] as String,
        externalId: json['external_id'] as String?,
        workoutDate: DateTime.parse(json['workout_date'] as String),
        startedAt: DateTime.parse(json['started_at'] as String),
        endedAt: DateTime.parse(json['ended_at'] as String),
        distanceKm: (json['distance_km'] as num).toDouble(),
        durationSeconds: json['duration_seconds'] as int,
        avgPaceSecondsPerKm: json['avg_pace_seconds_per_km'] as int?,
        avgHeartRate: json['avg_heart_rate'] as int?,
        maxHeartRate: json['max_heart_rate'] as int?,
        totalCalories: json['total_calories'] as int?,
        avgCadence: json['avg_cadence'] as int?,
        totalElevationGainM:
            (json['total_elevation_gain_m'] as num?)?.toDouble(),
        splits: json['splits'] as List<dynamic>?,
        heartRateData: json['heart_rate_data'] as List<dynamic>?,
        routePolyline: json['route_polyline'] as String?,
        weatherTempC: (json['weather_temp_c'] as num?)?.toDouble(),
        weatherHumidity: json['weather_humidity'] as int?,
        weatherCondition: json['weather_condition'] as String?,
        memo: json['memo'] as String?,
        weatherContext: json['weather_context'] != null
            ? Map<String, dynamic>.from(json['weather_context'] as Map)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'session_id': sessionId,
        'source': source,
        'external_id': externalId,
        'workout_date': workoutDate.toIso8601String().substring(0, 10),
        'started_at': startedAt.toIso8601String(),
        'ended_at': endedAt.toIso8601String(),
        'distance_km': distanceKm,
        'duration_seconds': durationSeconds,
        'avg_pace_seconds_per_km': avgPaceSecondsPerKm,
        'avg_heart_rate': avgHeartRate,
        'max_heart_rate': maxHeartRate,
        'total_calories': totalCalories,
        'avg_cadence': avgCadence,
        'total_elevation_gain_m': totalElevationGainM,
        'splits': splits,
        'heart_rate_data': heartRateData,
        'route_polyline': routePolyline,
        'weather_temp_c': weatherTempC,
        'weather_humidity': weatherHumidity,
        'weather_condition': weatherCondition,
        'memo': memo,
        'weather_context': weatherContext,
      };
}
