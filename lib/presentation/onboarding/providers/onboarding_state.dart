import '../../../data/models/race_record.dart';

/// 온보딩 전체 상태 모델
class OnboardingState {
  // B-1 프로필
  final String nickname;
  final String? gender;
  final int? birthYear;
  final double? heightCm;
  final double? weightKg;

  // B-2 러닝 경험
  final String? runningExperience;
  final int? weeklyAvailableDays;

  // B-3 데이터 연동
  final bool healthKitConnected;
  final bool stravaConnected;

  // B-4 대회 기록
  final List<RaceRecord> raceRecords;

  // B-5 목표 설정
  final String? goalRaceName;
  final DateTime? goalRaceDate;
  final double? goalDistanceKm;
  final int? goalTimeSeconds;
  final bool justFinishGoal;
  final int? trainingWeeks;

  // UI 상태
  final bool isLoading;
  final String? error;

  const OnboardingState({
    this.nickname = '',
    this.gender,
    this.birthYear,
    this.heightCm,
    this.weightKg,
    this.runningExperience,
    this.weeklyAvailableDays,
    this.healthKitConnected = false,
    this.stravaConnected = false,
    this.raceRecords = const [],
    this.goalRaceName,
    this.goalRaceDate,
    this.goalDistanceKm,
    this.goalTimeSeconds,
    this.justFinishGoal = false,
    this.trainingWeeks,
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    String? nickname,
    String? gender,
    int? birthYear,
    double? heightCm,
    double? weightKg,
    String? runningExperience,
    int? weeklyAvailableDays,
    bool? healthKitConnected,
    bool? stravaConnected,
    List<RaceRecord>? raceRecords,
    String? goalRaceName,
    DateTime? goalRaceDate,
    double? goalDistanceKm,
    int? goalTimeSeconds,
    bool? justFinishGoal,
    int? trainingWeeks,
    bool? isLoading,
    String? error,
  }) =>
      OnboardingState(
        nickname: nickname ?? this.nickname,
        gender: gender ?? this.gender,
        birthYear: birthYear ?? this.birthYear,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        runningExperience: runningExperience ?? this.runningExperience,
        weeklyAvailableDays: weeklyAvailableDays ?? this.weeklyAvailableDays,
        healthKitConnected: healthKitConnected ?? this.healthKitConnected,
        stravaConnected: stravaConnected ?? this.stravaConnected,
        raceRecords: raceRecords ?? this.raceRecords,
        goalRaceName: goalRaceName ?? this.goalRaceName,
        goalRaceDate: goalRaceDate ?? this.goalRaceDate,
        goalDistanceKm: goalDistanceKm ?? this.goalDistanceKm,
        goalTimeSeconds: goalTimeSeconds ?? this.goalTimeSeconds,
        justFinishGoal: justFinishGoal ?? this.justFinishGoal,
        trainingWeeks: trainingWeeks ?? this.trainingWeeks,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}
