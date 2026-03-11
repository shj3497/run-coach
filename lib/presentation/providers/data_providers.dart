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
import '../../data/services/location_service.dart';
import '../../data/services/strava_service.dart';
import '../../data/services/weather_service.dart';
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
// Weather & Location Services
// -----------------------------------------------------------------------------

/// 위치 서비스 인스턴스
final locationServiceProvider = Provider<LocationService>((ref) {
  return const LocationService();
});

/// 날씨 서비스 인스턴스
final weatherServiceProvider = Provider<WeatherService>((ref) {
  return WeatherService();
});

/// 현재 날씨 데이터 (자동으로 위치 가져와서 조회)
///
/// 위치 권한이 없거나 API 오류 시 null을 반환합니다.
final currentWeatherProvider = FutureProvider<WeatherData?>((ref) async {
  try {
    final locationService = ref.watch(locationServiceProvider);
    final weatherService = ref.watch(weatherServiceProvider);

    // 권한 확인 → 없으면 요청
    final hasPermission = await locationService.checkPermission();
    if (!hasPermission) {
      final granted = await locationService.requestPermission();
      if (!granted) return null;
    }

    // 먼저 마지막으로 알려진 위치 시도 (빠름)
    var position = await locationService.getLastKnownPosition();

    // 없으면 현재 위치 조회
    position ??= await locationService.getCurrentPosition();

    if (position == null) return null;

    return await weatherService.getCurrentWeather(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  } catch (e) {
    return null;
  }
});

// -----------------------------------------------------------------------------
// 활성 플랜 관련
// -----------------------------------------------------------------------------

/// 플랜 ID로 단일 플랜 조회
final planByIdProvider =
    FutureProvider.family<TrainingPlan?, String>((ref, planId) async {
  final planRepo = ref.watch(planRepositoryProvider);
  return await planRepo.getPlanById(planId);
});

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
    weatherService: ref.watch(weatherServiceProvider),
    locationService: ref.watch(locationServiceProvider),
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

/// 운동 기록 상세 조회 (Strava 상세 데이터 lazy-load 포함)
///
/// splits가 없는 Strava 운동의 경우 상세 API를 호출하여
/// splits, 심박수 시계열, 케이던스를 보강한 후 DB에 저장합니다.
/// 한번 저장되면 다음 조회부터는 추가 API 호출 없이 DB에서 읽습니다.
final enrichedWorkoutLogProvider =
    FutureProvider.family<WorkoutLog?, String>((ref, workoutId) async {
  final workoutRepo = ref.watch(workoutRepositoryProvider);
  final workout = await workoutRepo.getWorkoutLogById(workoutId);
  if (workout == null) return null;

  // Strava 워크아웃이고 상세 데이터가 부족하면 Strava API 재호출
  // - splits 없음
  // - heart_rate_data에 altitude_m/velocity_mps 키 없음 (구 포맷)
  if (workout.source == 'strava' &&
      workout.externalId != null &&
      _needsStravaEnrichment(workout)) {
    try {
      final stravaService = ref.watch(stravaServiceProvider);
      final detailedLog = await stravaService.getActivityDetail(
        userId: workout.userId,
        activityId: int.parse(workout.externalId!),
      );

      if (detailedLog != null) {
        final updates = <String, dynamic>{};
        if (detailedLog.splits != null) {
          updates['splits'] = detailedLog.splits;
        }
        // 스트림 데이터는 항상 최신으로 덮어쓰기 (superset)
        if (detailedLog.heartRateData != null) {
          updates['heart_rate_data'] = detailedLog.heartRateData;
        }
        if (detailedLog.avgCadence != null && workout.avgCadence == null) {
          updates['avg_cadence'] = detailedLog.avgCadence;
        }

        if (updates.isNotEmpty) {
          return await workoutRepo.updateWorkoutLogFields(
              workoutId, updates);
        }
      }
    } catch (_) {
      // Strava 조회 실패 시 기존 데이터 반환
    }
  }

  return workout;
});

/// Strava enrichment가 필요한지 판단
///
/// splits가 없거나, heart_rate_data에 distance_m/altitude_m/velocity_mps 키가
/// 없으면 Strava API 재호출이 필요합니다.
bool _needsStravaEnrichment(WorkoutLog workout) {
  if (workout.splits == null) return true;

  final hrData = workout.heartRateData;
  if (hrData == null || hrData.isEmpty) return true;

  // 첫 번째 데이터 포인트에 필수 키들이 있는지 확인
  final firstPoint = hrData.first;
  if (firstPoint is Map<String, dynamic>) {
    if (!firstPoint.containsKey('distance_m')) {
      return true;
    }
  }

  return false;
}

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
