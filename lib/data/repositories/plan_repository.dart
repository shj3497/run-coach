import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/training_plan.dart';
import '../models/training_session.dart';
import '../models/training_week.dart';

/// training_plans, training_weeks, training_sessions 테이블 데이터 접근
class PlanRepository {
  final SupabaseClient _client;

  PlanRepository(this._client);

  SupabaseQueryBuilder get _plansTable => _client.from('training_plans');
  SupabaseQueryBuilder get _weeksTable => _client.from('training_weeks');
  SupabaseQueryBuilder get _sessionsTable => _client.from('training_sessions');

  // ---------------------------------------------------------------------------
  // Training Plans
  // ---------------------------------------------------------------------------

  /// 사용자의 활성 플랜 조회 (최대 1개)
  Future<TrainingPlan?> getActivePlan(String userId) async {
    final response = await _plansTable
        .select()
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();
    return response == null ? null : TrainingPlan.fromJson(response);
  }

  /// 사용자의 전체 플랜 목록 (최신순)
  Future<List<TrainingPlan>> getUserPlans(String userId) async {
    final response = await _plansTable
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    return (response as List)
        .map((json) => TrainingPlan.fromJson(json))
        .toList();
  }

  /// 플랜 + 주차 + 세션 일괄 생성 (weekNumber 기반 매핑)
  Future<TrainingPlan> createPlanWithMapping({
    required TrainingPlan plan,
    required List<TrainingWeek> weeks,
    required Map<int, List<TrainingSession>> weekNumberToSessions,
  }) async {
    // 1. 플랜 생성
    final planResponse = await _plansTable
        .insert(plan.toJson())
        .select()
        .single();
    final savedPlan = TrainingPlan.fromJson(planResponse);

    try {
      // 2. 주차 일괄 생성
      final weekJsonList = weeks.map((w) {
        final json = w.toJson();
        json['plan_id'] = savedPlan.id;
        return json;
      }).toList();

      final weekResponses = await _weeksTable
          .insert(weekJsonList)
          .select();
      final savedWeeks = (weekResponses as List)
          .map((json) => TrainingWeek.fromJson(json))
          .toList();

      // weekNumber -> weekId 매핑
      final weekIdMap = <int, String>{};
      for (final w in savedWeeks) {
        weekIdMap[w.weekNumber] = w.id;
      }

      // 3. 세션 일괄 생성 (weekNumber 기반 매핑)
      final allSessionJsons = <Map<String, dynamic>>[];
      for (final entry in weekNumberToSessions.entries) {
        final weekId = weekIdMap[entry.key];
        if (weekId == null) continue;

        for (final session in entry.value) {
          final json = session.toJson();
          json['plan_id'] = savedPlan.id;
          json['week_id'] = weekId;
          allSessionJsons.add(json);
        }
      }

      if (allSessionJsons.isNotEmpty) {
        await _sessionsTable.insert(allSessionJsons);
      }

      return savedPlan;
    } catch (e) {
      // 오류 시 생성된 플랜 정리
      await _plansTable.delete().eq('id', savedPlan.id);
      rethrow;
    }
  }

  /// 플랜 상태 업데이트
  Future<void> updatePlanStatus(String planId, String status) async {
    await _plansTable
        .update({
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', planId);
  }

  /// 플랜 삭제 (sessions -> weeks -> plan 순서)
  Future<void> deletePlan(String planId) async {
    await _sessionsTable.delete().eq('plan_id', planId);
    await _weeksTable.delete().eq('plan_id', planId);
    await _plansTable.delete().eq('id', planId);
  }

  // ---------------------------------------------------------------------------
  // Training Weeks
  // ---------------------------------------------------------------------------

  /// 플랜의 전체 주차 목록 (주차순)
  Future<List<TrainingWeek>> getWeeksByPlan(String planId) async {
    final response = await _weeksTable
        .select()
        .eq('plan_id', planId)
        .order('week_number', ascending: true);
    return (response as List)
        .map((json) => TrainingWeek.fromJson(json))
        .toList();
  }

  /// 현재 진행 중인 주차 조회 (날짜 기반)
  Future<TrainingWeek?> getCurrentWeek(String planId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final response = await _weeksTable
        .select()
        .eq('plan_id', planId)
        .lte('start_date', today)
        .gte('end_date', today)
        .maybeSingle();
    return response == null ? null : TrainingWeek.fromJson(response);
  }

  // ---------------------------------------------------------------------------
  // Training Sessions
  // ---------------------------------------------------------------------------

  /// 주차별 세션 목록 (날짜순)
  Future<List<TrainingSession>> getSessionsByWeek(String weekId) async {
    final response = await _sessionsTable
        .select()
        .eq('week_id', weekId)
        .order('session_date', ascending: true);
    return (response as List)
        .map((json) => TrainingSession.fromJson(json))
        .toList();
  }

  /// 플랜 + 날짜로 세션 조회
  Future<List<TrainingSession>> getSessionsByPlanAndDate(
    String planId,
    DateTime date,
  ) async {
    final dateStr = date.toIso8601String().substring(0, 10);
    final response = await _sessionsTable
        .select()
        .eq('plan_id', planId)
        .eq('session_date', dateStr)
        .order('day_of_week', ascending: true);
    return (response as List)
        .map((json) => TrainingSession.fromJson(json))
        .toList();
  }

  /// 오늘의 훈련 세션 조회
  Future<List<TrainingSession>> getTodaySessions(String planId) async {
    return getSessionsByPlanAndDate(planId, DateTime.now());
  }

  /// 세션 상태 업데이트
  Future<void> updateSessionStatus(
    String sessionId,
    String status, {
    DateTime? completedAt,
  }) async {
    final updates = <String, dynamic>{
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (completedAt != null) {
      updates['completed_at'] = completedAt.toIso8601String();
    } else if (status == 'completed') {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }
    await _sessionsTable.update(updates).eq('id', sessionId);
  }

  /// 플랜 전체 세션 목록 (날짜순)
  Future<List<TrainingSession>> getAllSessionsByPlan(String planId) async {
    final response = await _sessionsTable
        .select()
        .eq('plan_id', planId)
        .order('session_date', ascending: true);
    return (response as List)
        .map((json) => TrainingSession.fromJson(json))
        .toList();
  }

  /// 날짜 범위로 세션 조회
  Future<List<TrainingSession>> getSessionsByDateRange(
    String planId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final startStr = startDate.toIso8601String().substring(0, 10);
    final endStr = endDate.toIso8601String().substring(0, 10);
    final response = await _sessionsTable
        .select()
        .eq('plan_id', planId)
        .gte('session_date', startStr)
        .lte('session_date', endStr)
        .order('session_date', ascending: true);
    return (response as List)
        .map((json) => TrainingSession.fromJson(json))
        .toList();
  }
}
