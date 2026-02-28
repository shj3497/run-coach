/// 대회 기록 모델
/// DB 테이블: race_records
class RaceRecord {
  final String id;
  final String userId;
  final String raceName;
  final DateTime raceDate;
  final double distanceKm;
  final int finishTimeSeconds;
  final double? vdotScore;
  final String? memo;
  final DateTime createdAt;
  final DateTime updatedAt;

  const RaceRecord({
    required this.id,
    required this.userId,
    required this.raceName,
    required this.raceDate,
    required this.distanceKm,
    required this.finishTimeSeconds,
    this.vdotScore,
    this.memo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory RaceRecord.fromJson(Map<String, dynamic> json) => RaceRecord(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        raceName: json['race_name'] as String,
        raceDate: DateTime.parse(json['race_date'] as String),
        distanceKm: (json['distance_km'] as num).toDouble(),
        finishTimeSeconds: json['finish_time_seconds'] as int,
        vdotScore: (json['vdot_score'] as num?)?.toDouble(),
        memo: json['memo'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        updatedAt: DateTime.parse(json['updated_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'race_name': raceName,
        'race_date': raceDate.toIso8601String().substring(0, 10),
        'distance_km': distanceKm,
        'finish_time_seconds': finishTimeSeconds,
        'vdot_score': vdotScore,
        'memo': memo,
      };

  RaceRecord copyWith({
    String? id,
    String? userId,
    String? raceName,
    DateTime? raceDate,
    double? distanceKm,
    int? finishTimeSeconds,
    double? vdotScore,
    String? memo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      RaceRecord(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        raceName: raceName ?? this.raceName,
        raceDate: raceDate ?? this.raceDate,
        distanceKm: distanceKm ?? this.distanceKm,
        finishTimeSeconds: finishTimeSeconds ?? this.finishTimeSeconds,
        vdotScore: vdotScore ?? this.vdotScore,
        memo: memo ?? this.memo,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
