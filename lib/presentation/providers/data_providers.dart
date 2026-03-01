import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/coaching_message.dart';
import '../../data/models/training_plan.dart';
import '../../data/models/training_session.dart';
import '../../data/models/training_week.dart';
import '../../data/models/workout_log.dart';
import '../../data/repositories/coaching_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/race_record_repository.dart';
import '../../data/repositories/workout_repository.dart';
import '../../data/services/healthkit_service.dart';
import '../../data/services/llm/llm_provider.dart';
import '../../data/services/llm/openai_provider.dart';
import '../../data/services/strava_service.dart';
import '../../domain/usecases/generate_training_plan.dart';
import '../../domain/usecases/match_workout_to_session.dart';
import '../../domain/usecases/process_workout.dart';
import '../auth/providers/auth_providers.dart';

// -----------------------------------------------------------------------------
// LLM Provider
// -----------------------------------------------------------------------------

/// LLMProvider 인스턴스 (OpenAI 구현체)
final llmProviderProvider = Provider<LLMProvider>((ref) {
  return OpenAIProvider();
});

// -----------------------------------------------------------------------------
// Repositories
// -----------------------------------------------------------------------------

final raceRecordRepositoryProvider = Provider<RaceRecordRepository>((ref) {
  return RaceRecordRepository(ref.watch(supabaseClientProvider));
});

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(supabaseClientProvider));
});

final coachingRepositoryProvider = Provider<CoachingRepository>((ref) {
  return CoachingRepository(ref.watch(supabaseClientProvider));
});

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  return WorkoutRepository(ref.watch(supabaseClientProvider));
});

// -----------------------------------------------------------------------------
// External Services (HealthKit / Strava)
// -----------------------------------------------------------------------------

/// HealthKit 서비스 인스턴스
final healthKitServiceProvider = Provider<HealthKitService>((ref) {
  return HealthKitService();
});

/// Strava API 서비스 인스턴스
final stravaServiceProvider = Provider<StravaService>((ref) {
  return StravaService(
    supabaseClient: ref.watch(supabaseClientProvider),
  );
});

// -----------------------------------------------------------------------------
// 활성 플랜 관련
// -----------------------------------------------------------------------------

/// 현재 사용자의 활성 훈련 플랜
final activePlanProvider = FutureProvider<TrainingPlan?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getActivePlan(user.id);
});

/// 활성 플랜의 전체 주차 목록
final activePlanWeeksProvider =
    FutureProvider<List<TrainingWeek>>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return [];
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getWeeksByPlan(plan.id);
});

/// 활성 플랜의 현재 주차 (DB 기반)
final dbCurrentWeekProvider = FutureProvider<TrainingWeek?>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return null;
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getCurrentWeek(plan.id);
});

/// 오늘의 훈련 세션 목록
final todaySessionsProvider =
    FutureProvider<List<TrainingSession>>((ref) async {
  final plan = await ref.watch(activePlanProvider.future);
  if (plan == null) return [];
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getTodaySessions(plan.id);
});

/// 특정 주차의 세션 목록 (DB 기반)
final dbWeekSessionsProvider =
    FutureProvider.family<List<TrainingSession>, String>(
        (ref, weekId) async {
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getSessionsByWeek(weekId);
});

// -----------------------------------------------------------------------------
// 코칭 메시지 관련
// -----------------------------------------------------------------------------

/// 읽지 않은 코칭 메시지 개수
final unreadCoachingCountProvider = FutureProvider<int>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return 0;
  final coachingRepo = ref.watch(coachingRepositoryProvider);
  return await coachingRepo.getUnreadCount(user.id);
});

/// 최근 코칭 메시지 목록 (최대 20개)
final recentCoachingMessagesProvider =
    FutureProvider<List<CoachingMessage>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final coachingRepo = ref.watch(coachingRepositoryProvider);
  return await coachingRepo.getMessages(user.id, limit: 20);
});

/// 활성 플랜의 코칭 메시지 목록
final planCoachingMessagesProvider =
    FutureProvider<List<CoachingMessage>>((ref) async {
  final user = ref.watch(currentUserProvider);
  final plan = await ref.watch(activePlanProvider.future);
  if (user == null || plan == null) return [];
  final coachingRepo = ref.watch(coachingRepositoryProvider);
  return await coachingRepo.getMessages(user.id, planId: plan.id);
});

// -----------------------------------------------------------------------------
// 사용자 전체 플랜 목록
// -----------------------------------------------------------------------------

final userPlansProvider =
    FutureProvider<List<TrainingPlan>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getUserPlans(user.id);
});

// -----------------------------------------------------------------------------
// Use Cases
// -----------------------------------------------------------------------------

/// 훈련표 생성 유스케이스
final generateTrainingPlanProvider = Provider<GenerateTrainingPlan>((ref) {
  return GenerateTrainingPlan(llmProvider: ref.watch(llmProviderProvider));
});

/// 운동-세션 매칭 유스케이스
final matchWorkoutToSessionProvider =
    Provider<MatchWorkoutToSession>((ref) {
  return const MatchWorkoutToSession();
});

/// 워크아웃 처리 파이프라인 유스케이스
final processWorkoutUseCaseProvider =
    Provider<ProcessWorkoutUseCase>((ref) {
  return ProcessWorkoutUseCase(
    workoutRepository: ref.watch(workoutRepositoryProvider),
    planRepository: ref.watch(planRepositoryProvider),
    matchUseCase: ref.watch(matchWorkoutToSessionProvider),
  );
});

// -----------------------------------------------------------------------------
// 운동 기록 관련
// -----------------------------------------------------------------------------

/// 단일 운동 기록 조회
final workoutLogProvider =
    FutureProvider.family<WorkoutLog?, String>((ref, workoutId) async {
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  return await workoutRepo.getWorkoutLogById(workoutId);
});

/// 이번 주 운동 기록 목록
final thisWeekWorkoutLogsProvider =
    FutureProvider<List<WorkoutLog>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  return await workoutRepo.getThisWeekWorkoutLogs(user.id);
});

/// 최근 운동 기록 (5개)
final recentWorkoutLogsProvider =
    FutureProvider<List<WorkoutLog>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  return await workoutRepo.getRecentWorkouts(user.id, count: 5);
});

/// 세션에 연결된 운동 기록
final workoutLogBySessionProvider =
    FutureProvider.family<WorkoutLog?, String>((ref, sessionId) async {
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  return await workoutRepo.getWorkoutBySessionId(sessionId);
});

/// 월간 운동 요약
final monthlyWorkoutSummaryProvider = FutureProvider.family<
    MonthlyWorkoutSummary, ({int year, int month})>(
  (ref, params) async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return MonthlyWorkoutSummary(
        year: params.year,
        month: params.month,
        totalWorkouts: 0,
        totalDistanceKm: 0,
        totalDurationSeconds: 0,
        totalCalories: 0,
      );
    }
    final workoutRepo = ref.watch(workoutRepositoryProvider);
    return await workoutRepo.getMonthlySummary(
      user.id,
      params.year,
      params.month,
    );
  },
);
