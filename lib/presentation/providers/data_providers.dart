import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/coaching_message.dart';
import '../../data/models/training_plan.dart';
import '../../data/models/training_session.dart';
import '../../data/models/training_week.dart';
import '../../data/repositories/coaching_repository.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/services/llm/llm_provider.dart';
import '../../data/services/llm/openai_provider.dart';
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

final planRepositoryProvider = Provider<PlanRepository>((ref) {
  return PlanRepository(ref.watch(supabaseClientProvider));
});

final coachingRepositoryProvider = Provider<CoachingRepository>((ref) {
  return CoachingRepository(ref.watch(supabaseClientProvider));
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
