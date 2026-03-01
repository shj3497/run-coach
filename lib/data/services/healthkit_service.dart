import 'dart:io';

import 'package:health/health.dart';

import '../models/workout_log.dart';

/// HealthKit 연동 서비스
///
/// Apple HealthKit에서 러닝 워크아웃 데이터를 읽어와
/// [WorkoutLog] 모델로 변환합니다.
/// iOS 전용이며, Android에서는 모든 메서드가 빈 결과를 반환합니다.
class HealthKitService {
  HealthKitService({Health? healthFactory})
      : _health = healthFactory ?? Health();

  final Health _health;

  /// HealthKit에 접근 가능한 데이터 타입 목록
  static const List<HealthDataType> _readTypes = [
    HealthDataType.WORKOUT,
    HealthDataType.HEART_RATE,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.ACTIVE_ENERGY_BURNED,
  ];

  // ---------------------------------------------------------------------------
  // 권한
  // ---------------------------------------------------------------------------

  /// HealthKit 읽기 권한 요청
  ///
  /// iOS가 아닌 플랫폼에서는 항상 false를 반환합니다.
  /// 반환값: 권한이 부여되었으면 true
  Future<bool> requestPermissions() async {
    if (!Platform.isIOS) return false;

    try {
      final permissions =
          _readTypes.map((_) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: permissions,
      );
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// HealthKit 권한 상태 확인
  ///
  /// iOS가 아닌 플랫폼에서는 항상 false를 반환합니다.
  Future<bool> hasPermissions() async {
    if (!Platform.isIOS) return false;

    try {
      final hasPerms = await _health.hasPermissions(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      return hasPerms ?? false;
    } catch (e) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // 워크아웃 데이터 읽기
  // ---------------------------------------------------------------------------

  /// 지정된 날짜 범위의 러닝 워크아웃을 가져옵니다.
  ///
  /// [startDate] 검색 시작 날짜
  /// [endDate] 검색 종료 날짜
  /// [userId] WorkoutLog에 설정할 사용자 ID
  ///
  /// 반환: WorkoutLog 목록 (최신순 정렬)
  Future<List<WorkoutLog>> getWorkouts({
    required DateTime startDate,
    required DateTime endDate,
    required String userId,
  }) async {
    if (!Platform.isIOS) return [];

    try {
      final healthData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.WORKOUT],
        startTime: startDate,
        endTime: endDate,
      );

      // 러닝 워크아웃만 필터링
      final runningWorkouts = healthData.where((data) {
        if (data.value is WorkoutHealthValue) {
          final workout = data.value as WorkoutHealthValue;
          return workout.workoutActivityType ==
              HealthWorkoutActivityType.RUNNING;
        }
        return false;
      }).toList();

      // 최신순 정렬
      runningWorkouts.sort((a, b) => b.dateFrom.compareTo(a.dateFrom));

      // 각 워크아웃에 대해 추가 데이터(심박수 등)를 가져와 WorkoutLog로 변환
      final workoutLogs = <WorkoutLog>[];
      for (final workoutData in runningWorkouts) {
        final log = await _convertToWorkoutLog(
          workoutData: workoutData,
          userId: userId,
        );
        if (log != null) {
          workoutLogs.add(log);
        }
      }

      return workoutLogs;
    } catch (e) {
      return [];
    }
  }

  /// 마지막 동기화 이후의 새로운 워크아웃만 가져옵니다.
  ///
  /// [lastSyncAt] 마지막 동기화 시간. null이면 최근 30일 데이터를 가져옵니다.
  /// [userId] WorkoutLog에 설정할 사용자 ID
  Future<List<WorkoutLog>> getNewWorkoutsSince({
    DateTime? lastSyncAt,
    required String userId,
  }) async {
    final startDate =
        lastSyncAt ?? DateTime.now().subtract(const Duration(days: 30));
    final endDate = DateTime.now();

    return getWorkouts(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  /// 특정 날짜의 워크아웃을 가져옵니다.
  ///
  /// [date] 조회할 날짜
  /// [userId] WorkoutLog에 설정할 사용자 ID
  Future<List<WorkoutLog>> getWorkoutsByDate({
    required DateTime date,
    required String userId,
  }) async {
    final startDate = DateTime(date.year, date.month, date.day);
    final endDate = startDate.add(const Duration(days: 1));

    return getWorkouts(
      startDate: startDate,
      endDate: endDate,
      userId: userId,
    );
  }

  // ---------------------------------------------------------------------------
  // 심박수 데이터
  // ---------------------------------------------------------------------------

  /// 특정 시간 범위의 심박수 시계열 데이터를 가져옵니다.
  ///
  /// 반환: [{"timestamp": "ISO8601", "bpm": int}, ...] 형태의 리스트
  Future<List<Map<String, dynamic>>> getHeartRateData({
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    if (!Platform.isIOS) return [];

    try {
      final heartRateData = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startTime,
        endTime: endTime,
      );

      return heartRateData.map((data) {
        final numValue = data.value as NumericHealthValue;
        return <String, dynamic>{
          'timestamp': data.dateFrom.toIso8601String(),
          'bpm': numValue.numericValue.round(),
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // 내부 변환 로직
  // ---------------------------------------------------------------------------

  /// HealthDataPoint를 WorkoutLog로 변환합니다.
  Future<WorkoutLog?> _convertToWorkoutLog({
    required HealthDataPoint workoutData,
    required String userId,
  }) async {
    try {
      final workoutValue = workoutData.value as WorkoutHealthValue;
      final startTime = workoutData.dateFrom;
      final endTime = workoutData.dateTo;
      final durationSeconds = endTime.difference(startTime).inSeconds;

      if (durationSeconds <= 0) return null;

      // 거리 (totalDistance는 m 단위 → km로 변환)
      final distanceKm =
          (workoutValue.totalDistance ?? 0) / 1000.0;

      // 너무 짧은 운동은 무시 (100m 미만 또는 60초 미만)
      if (distanceKm < 0.1 || durationSeconds < 60) return null;

      // 평균 페이스 계산 (초/km)
      final avgPaceSecondsPerKm = distanceKm > 0
          ? (durationSeconds / distanceKm).round()
          : null;

      // 칼로리
      final totalCalories =
          (workoutValue.totalEnergyBurned ?? 0).round();

      // 심박수 데이터 가져오기
      final heartRateDataList = await getHeartRateData(
        startTime: startTime,
        endTime: endTime,
      );

      // 평균/최대 심박수 계산
      int? avgHeartRate;
      int? maxHeartRate;
      if (heartRateDataList.isNotEmpty) {
        final bpmValues = heartRateDataList
            .map((hr) => hr['bpm'] as int)
            .toList();
        avgHeartRate =
            (bpmValues.reduce((a, b) => a + b) / bpmValues.length).round();
        maxHeartRate = bpmValues.reduce((a, b) => a > b ? a : b);
      }

      // km별 splits 생성 (시간 기반 균등 분배 - HealthKit은 세부 splits를 제공하지 않음)
      final splits = _generateEstimatedSplits(
        distanceKm: distanceKm,
        durationSeconds: durationSeconds,
      );

      // HealthKit UUID를 external_id로 사용
      final externalId = workoutData.uuid;

      final now = DateTime.now();

      return WorkoutLog(
        id: '', // DB가 생성
        userId: userId,
        sessionId: null,
        source: 'healthkit',
        externalId: externalId,
        workoutDate: DateTime(startTime.year, startTime.month, startTime.day),
        startedAt: startTime,
        endedAt: endTime,
        distanceKm: double.parse(distanceKm.toStringAsFixed(2)),
        durationSeconds: durationSeconds,
        avgPaceSecondsPerKm: avgPaceSecondsPerKm,
        avgHeartRate: avgHeartRate,
        maxHeartRate: maxHeartRate,
        totalCalories: totalCalories > 0 ? totalCalories : null,
        avgCadence: null, // HealthKit에서는 케이던스를 직접 제공하지 않음
        totalElevationGainM: null, // HealthKit에서는 고도를 직접 제공하지 않음
        splits: splits.isNotEmpty ? splits : null,
        heartRateData:
            heartRateDataList.isNotEmpty ? heartRateDataList : null,
        routePolyline: null,
        weatherTempC: null,
        weatherHumidity: null,
        weatherCondition: null,
        memo: null,
        createdAt: now,
        updatedAt: now,
      );
    } catch (e) {
      return null;
    }
  }

  /// km별 예상 splits를 생성합니다.
  ///
  /// HealthKit은 세부 구간별 페이스를 제공하지 않으므로,
  /// 평균 페이스를 기반으로 균등 분배합니다.
  List<Map<String, dynamic>> _generateEstimatedSplits({
    required double distanceKm,
    required int durationSeconds,
  }) {
    if (distanceKm <= 0) return [];

    final avgPacePerKm = durationSeconds / distanceKm;
    final fullKms = distanceKm.floor();
    final remainingKm = distanceKm - fullKms;

    final splits = <Map<String, dynamic>>[];

    for (int km = 1; km <= fullKms; km++) {
      splits.add({
        'km': km,
        'pace_seconds': avgPacePerKm.round(),
      });
    }

    // 마지막 부분 km (0.1km 이상일 때만)
    if (remainingKm >= 0.1) {
      splits.add({
        'km': fullKms + 1,
        'distance_km': double.parse(remainingKm.toStringAsFixed(2)),
        'pace_seconds': avgPacePerKm.round(),
      });
    }

    return splits;
  }
}
