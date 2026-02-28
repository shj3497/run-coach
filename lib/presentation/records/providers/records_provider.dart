import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Mock Data Models ───

/// 월간 요약 데이터
class MonthlySummary {
  final double totalDistanceKm;
  final int totalTimeSeconds;
  final int averagePaceSeconds; // 초/km
  final int totalWorkouts;

  const MonthlySummary({
    required this.totalDistanceKm,
    required this.totalTimeSeconds,
    required this.averagePaceSeconds,
    required this.totalWorkouts,
  });
}

/// 운동 기록 항목
class WorkoutRecord {
  final String id;
  final DateTime date;
  final String trainingType;
  final double distanceKm;
  final int durationSeconds;
  final int paceSeconds; // 초/km
  final int? heartRate;
  final String? source; // 'healthkit' | 'strava'

  const WorkoutRecord({
    required this.id,
    required this.date,
    required this.trainingType,
    required this.distanceKm,
    required this.durationSeconds,
    required this.paceSeconds,
    this.heartRate,
    this.source,
  });
}

// ─── Providers ───

/// 월간 요약 Provider (Phase 4 이후 HealthKit/Strava 연동 시 실제 데이터)
final monthlySummaryProvider = FutureProvider<MonthlySummary?>((ref) async {
  // Phase 4 이전에는 null (빈 상태)
  return null;
});

/// 운동 기록 목록 Provider (Phase 4 이후 실제 데이터)
final workoutRecordsProvider =
    FutureProvider<List<WorkoutRecord>>((ref) async {
  // Phase 4 이전에는 빈 리스트
  return [];
});

/// 기록 데이터 존재 여부
final hasRecordsProvider = Provider<bool>((ref) {
  final records = ref.watch(workoutRecordsProvider);
  return records.valueOrNull?.isNotEmpty ?? false;
});
