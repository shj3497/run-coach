import 'package:flutter/material.dart';

/// 훈련 존 타입 정의
enum TrainingZoneType {
  easy,
  marathon,
  threshold,
  interval,
  repetition,
  longRun,
  recovery,
  crossTraining,
  rest,
}

/// DB session_type 문자열 → TrainingZoneType 변환
TrainingZoneType trainingZoneTypeFromDbString(String dbValue) {
  switch (dbValue) {
    case 'easy':
      return TrainingZoneType.easy;
    case 'marathon_pace':
      return TrainingZoneType.marathon;
    case 'threshold':
      return TrainingZoneType.threshold;
    case 'interval':
      return TrainingZoneType.interval;
    case 'repetition':
      return TrainingZoneType.repetition;
    case 'long_run':
      return TrainingZoneType.longRun;
    case 'recovery':
      return TrainingZoneType.recovery;
    case 'cross_training':
      return TrainingZoneType.crossTraining;
    case 'rest':
      return TrainingZoneType.rest;
    default:
      return TrainingZoneType.easy;
  }
}

/// TrainingZoneType → DB session_type 문자열 변환
String trainingZoneTypeToDbString(TrainingZoneType type) {
  switch (type) {
    case TrainingZoneType.easy:
      return 'easy';
    case TrainingZoneType.marathon:
      return 'marathon_pace';
    case TrainingZoneType.threshold:
      return 'threshold';
    case TrainingZoneType.interval:
      return 'interval';
    case TrainingZoneType.repetition:
      return 'repetition';
    case TrainingZoneType.longRun:
      return 'long_run';
    case TrainingZoneType.recovery:
      return 'recovery';
    case TrainingZoneType.crossTraining:
      return 'cross_training';
    case TrainingZoneType.rest:
      return 'rest';
  }
}

/// 훈련 존별 컬러 및 라벨 정의
/// DESIGN_SYSTEM.md Training Zone Colors 기반
class TrainingZone {
  final TrainingZoneType type;
  final String label;
  final String shortLabel;
  final Color color;

  const TrainingZone({
    required this.type,
    required this.label,
    required this.shortLabel,
    required this.color,
  });

  /// 배지 배경색 (20% 투명도)
  Color get badgeBackground => color.withValues(alpha: 0.2);
}

class TrainingZones {
  TrainingZones._();

  static const Color easyColor = Color(0xFF34C759);
  static const Color marathonColor = Color(0xFF007AFF);
  static const Color thresholdColor = Color(0xFFFF9F0A);
  static const Color intervalColor = Color(0xFFFF6B35);
  static const Color repetitionColor = Color(0xFFFF3B30);
  static const Color longRunColor = Color(0xFFAF52DE);
  static const Color recoveryColor = Color(0xFF30D158);
  static const Color crossTrainingColor = Color(0xFF64D2FF);
  static const Color restColor = Color(0xFF8E8E93);

  static const TrainingZone easy = TrainingZone(
    type: TrainingZoneType.easy,
    label: '이지런',
    shortLabel: '이지런',
    color: easyColor,
  );

  static const TrainingZone marathon = TrainingZone(
    type: TrainingZoneType.marathon,
    label: '마라톤페이스',
    shortLabel: '마라톤페이스',
    color: marathonColor,
  );

  static const TrainingZone threshold = TrainingZone(
    type: TrainingZoneType.threshold,
    label: '템포런',
    shortLabel: '템포런',
    color: thresholdColor,
  );

  static const TrainingZone interval = TrainingZone(
    type: TrainingZoneType.interval,
    label: '인터벌',
    shortLabel: '인터벌',
    color: intervalColor,
  );

  static const TrainingZone repetition = TrainingZone(
    type: TrainingZoneType.repetition,
    label: '반복달리기',
    shortLabel: '반복달리기',
    color: repetitionColor,
  );

  static const TrainingZone longRun = TrainingZone(
    type: TrainingZoneType.longRun,
    label: '장거리런',
    shortLabel: '장거리런',
    color: longRunColor,
  );

  static const TrainingZone recovery = TrainingZone(
    type: TrainingZoneType.recovery,
    label: '회복런',
    shortLabel: '회복런',
    color: recoveryColor,
  );

  static const TrainingZone crossTraining = TrainingZone(
    type: TrainingZoneType.crossTraining,
    label: '크로스트레이닝',
    shortLabel: '크로스트레이닝',
    color: crossTrainingColor,
  );

  static const TrainingZone rest = TrainingZone(
    type: TrainingZoneType.rest,
    label: '휴식',
    shortLabel: '휴식',
    color: restColor,
  );

  static const List<TrainingZone> all = [
    easy,
    marathon,
    threshold,
    interval,
    repetition,
    longRun,
    recovery,
    crossTraining,
    rest,
  ];

  static TrainingZone fromType(TrainingZoneType type) {
    return all.firstWhere((zone) => zone.type == type);
  }
}
