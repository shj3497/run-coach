import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/workout_log.dart';

/// workout_logs 테이블 데이터 접근
///
/// 운동 기록의 CRUD, 월별 조회, 요약 통계, 세션 연결 등을 제공합니다.
class WorkoutRepository {
  final SupabaseClient _client;

  WorkoutRepository(this._client);

  SupabaseQueryBuilder get _table => _client.from('workout_logs');

  // ---------------------------------------------------------------------------
  // 조회
  // ---------------------------------------------------------------------------

  /// 사용자의 운동 기록 목록을 가져옵니다.
  ///
  /// [userId] 사용자 ID
  /// [startDate] 검색 시작일 (포함)
  /// [endDate] 검색 종료일 (포함)
  /// [limit] 최대 조회 수 (기본 50)
  /// [offset] 페이지네이션 오프셋
  ///
  /// 반환: WorkoutLog 목록 (최신순)
  Future<List<WorkoutLog>> getWorkoutLogs(
    String userId, {
    DateTime? startDate,
    DateTime? endDate,
    int limit = 50,
    int offset = 0,
  }) async {
    var query = _table.select().eq('user_id', userId);

    if (startDate != null) {
      query = query.gte(
        'workout_date',
        startDate.toIso8601String().substring(0, 10),
      );
    }
    if (endDate != null) {
      query = query.lte(
        'workout_date',
        endDate.toIso8601String().substring(0, 10),
      );
    }

    final response = await query
        .order('workout_date', ascending: false)
        .range(offset, offset + limit - 1);

    return (response as List)
        .map((json) => WorkoutLog.fromJson(json))
        .toList();
  }

  /// 단일 운동 기록을 조회합니다.
  ///
  /// [id] 워크아웃 로그 ID
  ///
  /// 반환: WorkoutLog 또는 null
  Future<WorkoutLog?> getWorkoutLogById(String id) async {
    final response = await _table.select().eq('id', id).maybeSingle();
    return response == null ? null : WorkoutLog.fromJson(response);
  }

  /// 특정 날짜의 운동 기록을 조회합니다.
  ///
  /// [userId] 사용자 ID
  /// [date] 조회할 날짜
  Future<List<WorkoutLog>> getWorkoutLogsByDate(
    String userId,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().substring(0, 10);

    final response = await _table
        .select()
        .eq('user_id', userId)
        .eq('workout_date', dateStr)
        .order('started_at', ascending: true);

    return (response as List)
        .map((json) => WorkoutLog.fromJson(json))
        .toList();
  }

  /// 월별 운동 기록을 가져옵니다.
  ///
  /// [userId] 사용자 ID
  /// [year] 연도
  /// [month] 월 (1~12)
  ///
  /// 반환: 해당 월의 WorkoutLog 목록 (날짜순)
  Future<List<WorkoutLog>> getWorkoutLogsByMonth(
    String userId,
    int year,
    int month,
  ) async {
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 0); // 해당 월의 마지막 날

    final startStr = startDate.toIso8601String().substring(0, 10);
    final endStr = endDate.toIso8601String().substring(0, 10);

    final response = await _table
        .select()
        .eq('user_id', userId)
        .gte('workout_date', startStr)
        .lte('workout_date', endStr)
        .order('workout_date', ascending: true);

    return (response as List)
        .map((json) => WorkoutLog.fromJson(json))
        .toList();
  }

  /// 특정 날짜 범위의 운동 기록 목록
  Future<List<WorkoutLog>> getWorkoutLogsByDateRange(
    String userId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().substring(0, 10);
    final endStr = endDate.toIso8601String().substring(0, 10);

    final response = await _table
        .select()
        .eq('user_id', userId)
        .gte('workout_date', startStr)
        .lte('workout_date', endStr)
        .order('workout_date', ascending: false);

    return (response as List)
        .map((json) => WorkoutLog.fromJson(json))
        .toList();
  }

  /// 외부 ID로 운동 기록을 조회합니다 (중복 체크용).
  ///
  /// [userId] 사용자 ID
  /// [source] 데이터 소스 ('healthkit' 또는 'strava')
  /// [externalId] 외부 시스템 ID
  ///
  /// 반환: 기존 WorkoutLog 또는 null
  Future<WorkoutLog?> getWorkoutByExternalId(
    String userId,
    String source,
    String externalId,
  ) async {
    final response = await _table
        .select()
        .eq('user_id', userId)
        .eq('source', source)
        .eq('external_id', externalId)
        .maybeSingle();

    return response == null ? null : WorkoutLog.fromJson(response);
  }

  /// 이번 주 운동 기록 (월~일)
  Future<List<WorkoutLog>> getThisWeekWorkoutLogs(String userId) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    return getWorkoutLogsByDateRange(userId, monday, sunday);
  }

  /// 최근 N개의 운동 기록
  Future<List<WorkoutLog>> getRecentWorkouts(
    String userId, {
    int count = 10,
  }) async {
    final response = await _table
        .select()
        .eq('user_id', userId)
        .order('workout_date', ascending: false)
        .limit(count);

    return (response as List)
        .map((json) => WorkoutLog.fromJson(json))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // 생성 / 수정 / 삭제
  // ---------------------------------------------------------------------------

  /// 운동 기록을 저장합니다.
  ///
  /// external_id가 있는 경우, 동일 소스의 중복 기록이 있으면 저장하지 않고
  /// 기존 기록을 반환합니다.
  ///
  /// [workoutLog] 저장할 운동 기록
  ///
  /// 반환: 저장된 WorkoutLog (DB가 생성한 id, created_at 포함)
  Future<WorkoutLog> createWorkoutLog(WorkoutLog workoutLog) async {
    // 중복 체크 (external_id가 있는 경우)
    if (workoutLog.externalId != null) {
      final existing = await getWorkoutByExternalId(
        workoutLog.userId,
        workoutLog.source,
        workoutLog.externalId!,
      );
      if (existing != null) return existing;
    }

    final response = await _table
        .insert(workoutLog.toJson())
        .select()
        .single();

    return WorkoutLog.fromJson(response);
  }

  /// 여러 운동 기록을 일괄 저장합니다.
  ///
  /// 각 기록의 external_id로 중복 체크를 수행하여,
  /// 새로운 기록만 저장합니다.
  ///
  /// [workoutLogs] 저장할 운동 기록 목록
  ///
  /// 반환: 실제로 저장된 WorkoutLog 목록 (기존에 있던 기록은 제외)
  Future<List<WorkoutLog>> createWorkoutLogsBatch(
    List<WorkoutLog> workoutLogs,
  ) async {
    if (workoutLogs.isEmpty) return [];

    final newLogs = <Map<String, dynamic>>[];

    for (final log in workoutLogs) {
      // external_id가 있으면 중복 체크
      if (log.externalId != null) {
        final existing = await getWorkoutByExternalId(
          log.userId,
          log.source,
          log.externalId!,
        );
        if (existing != null) continue;
      }
      newLogs.add(log.toJson());
    }

    if (newLogs.isEmpty) return [];

    final response = await _table.insert(newLogs).select();

    return (response as List)
        .map((json) => WorkoutLog.fromJson(json))
        .toList();
  }

  /// 운동 기록을 업데이트합니다.
  ///
  /// [workoutLog] 업데이트할 운동 기록 (id 필수)
  ///
  /// 반환: 업데이트된 WorkoutLog
  Future<WorkoutLog> updateWorkoutLog(WorkoutLog workoutLog) async {
    final updates = workoutLog.toJson();
    updates['updated_at'] = DateTime.now().toIso8601String();

    final response = await _table
        .update(updates)
        .eq('id', workoutLog.id)
        .select()
        .single();

    return WorkoutLog.fromJson(response);
  }

  /// 운동 기록의 특정 필드만 업데이트합니다.
  Future<WorkoutLog> updateWorkoutLogFields(
    String workoutId,
    Map<String, dynamic> updates,
  ) async {
    updates['updated_at'] = DateTime.now().toIso8601String();
    final response = await _table
        .update(updates)
        .eq('id', workoutId)
        .select()
        .single();
    return WorkoutLog.fromJson(response);
  }

  /// 운동 기록을 삭제합니다.
  ///
  /// [id] 삭제할 워크아웃 로그 ID
  Future<void> deleteWorkoutLog(String id) async {
    await _table.delete().eq('id', id);
  }

  // ---------------------------------------------------------------------------
  // 세션 연결
  // ---------------------------------------------------------------------------

  /// 운동 기록을 훈련 세션에 연결합니다.
  ///
  /// [workoutId] 운동 기록 ID
  /// [sessionId] 훈련 세션 ID
  ///
  /// 반환: 업데이트된 WorkoutLog
  Future<WorkoutLog> linkWorkoutToSession(
    String workoutId,
    String sessionId,
  ) async {
    final response = await _table
        .update({
          'session_id': sessionId,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', workoutId)
        .select()
        .single();

    return WorkoutLog.fromJson(response);
  }

  /// 운동 기록의 세션 연결을 해제합니다.
  ///
  /// [workoutId] 운동 기록 ID
  Future<void> unlinkWorkoutFromSession(String workoutId) async {
    await _table
        .update({
          'session_id': null,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', workoutId);
  }

  /// 특정 세션에 연결된 운동 기록을 조회합니다.
  ///
  /// [sessionId] 훈련 세션 ID
  ///
  /// 반환: 연결된 WorkoutLog 또는 null
  Future<WorkoutLog?> getWorkoutBySessionId(String sessionId) async {
    final response = await _table
        .select()
        .eq('session_id', sessionId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response == null ? null : WorkoutLog.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // 통계 / 요약
  // ---------------------------------------------------------------------------

  /// 월간 운동 요약을 계산합니다.
  ///
  /// [userId] 사용자 ID
  /// [year] 연도
  /// [month] 월 (1~12)
  ///
  /// 반환: 월간 요약 데이터
  Future<MonthlyWorkoutSummary> getMonthlySummary(
    String userId,
    int year,
    int month,
  ) async {
    final logs = await getWorkoutLogsByMonth(userId, year, month);

    if (logs.isEmpty) {
      return MonthlyWorkoutSummary(
        year: year,
        month: month,
        totalWorkouts: 0,
        totalDistanceKm: 0,
        totalDurationSeconds: 0,
        avgPaceSecondsPerKm: null,
        avgHeartRate: null,
        totalCalories: 0,
      );
    }

    final totalDistanceKm =
        logs.fold<double>(0, (sum, log) => sum + log.distanceKm);
    final totalDurationSeconds =
        logs.fold<int>(0, (sum, log) => sum + log.durationSeconds);

    // 평균 페이스: 총 시간 / 총 거리
    final avgPaceSecondsPerKm = totalDistanceKm > 0
        ? (totalDurationSeconds / totalDistanceKm).round()
        : null;

    // 평균 심박수: 심박수 데이터가 있는 기록만으로 계산
    final logsWithHr =
        logs.where((log) => log.avgHeartRate != null).toList();
    final avgHeartRate = logsWithHr.isNotEmpty
        ? (logsWithHr.fold<int>(
                0, (sum, log) => sum + log.avgHeartRate!) /
            logsWithHr.length)
            .round()
        : null;

    // 총 칼로리
    final totalCalories = logs.fold<int>(
      0,
      (sum, log) => sum + (log.totalCalories ?? 0),
    );

    return MonthlyWorkoutSummary(
      year: year,
      month: month,
      totalWorkouts: logs.length,
      totalDistanceKm: double.parse(totalDistanceKm.toStringAsFixed(2)),
      totalDurationSeconds: totalDurationSeconds,
      avgPaceSecondsPerKm: avgPaceSecondsPerKm,
      avgHeartRate: avgHeartRate,
      totalCalories: totalCalories,
    );
  }
}

/// 월간 운동 요약 데이터
class MonthlyWorkoutSummary {
  /// 연도
  final int year;

  /// 월 (1~12)
  final int month;

  /// 총 운동 횟수
  final int totalWorkouts;

  /// 총 거리 (km)
  final double totalDistanceKm;

  /// 총 운동 시간 (초)
  final int totalDurationSeconds;

  /// 평균 페이스 (초/km). 기록이 없으면 null
  final int? avgPaceSecondsPerKm;

  /// 평균 심박수. 심박수 데이터가 없으면 null
  final int? avgHeartRate;

  /// 총 소모 칼로리
  final int totalCalories;

  const MonthlyWorkoutSummary({
    required this.year,
    required this.month,
    required this.totalWorkouts,
    required this.totalDistanceKm,
    required this.totalDurationSeconds,
    this.avgPaceSecondsPerKm,
    this.avgHeartRate,
    required this.totalCalories,
  });

  /// 총 운동 시간을 표시 형식으로 반환
  String get formattedDuration {
    final hours = totalDurationSeconds ~/ 3600;
    final minutes = (totalDurationSeconds % 3600) ~/ 60;
    final seconds = totalDurationSeconds % 60;
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    }
    return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
  }

  /// 평균 페이스를 M:SS/km 형식으로 반환
  String? get formattedAvgPace {
    if (avgPaceSecondsPerKm == null) return null;
    final minutes = avgPaceSecondsPerKm! ~/ 60;
    final seconds = avgPaceSecondsPerKm! % 60;
    return "$minutes:${seconds.toString().padLeft(2, '0')}/km";
  }

  /// 운동이 없는 달인지 여부
  bool get isEmpty => totalWorkouts == 0;
}
