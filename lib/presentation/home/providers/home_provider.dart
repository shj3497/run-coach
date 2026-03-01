import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/training_zones.dart';
import '../../../data/models/workout_log.dart';
import '../../auth/providers/auth_providers.dart';
import '../../providers/data_providers.dart';

// ─── Data Models ───

/// 오늘의 훈련 세션 데이터
class TodaySession {
  final String id;
  final TrainingZoneType zoneType;
  final String title;
  final String? targetPace;
  final String? estimatedTime;
  final double? distanceKm;
  final String? description;
  final bool isCompleted;
  final WorkoutLog? workoutLog;

  const TodaySession({
    required this.id,
    required this.zoneType,
    required this.title,
    this.targetPace,
    this.estimatedTime,
    this.distanceKm,
    this.description,
    this.isCompleted = false,
    this.workoutLog,
  });
}

/// 이번 주 진행률 데이터
class WeeklyProgress {
  final int completedSessions;
  final int totalSessions;
  final double completedKm;
  final double totalKm;

  const WeeklyProgress({
    required this.completedSessions,
    required this.totalSessions,
    required this.completedKm,
    required this.totalKm,
  });

  double get sessionProgress =>
      totalSessions > 0 ? completedSessions / totalSessions : 0.0;

  double get distanceProgress =>
      totalKm > 0 ? completedKm / totalKm : 0.0;
}

/// 코칭 메시지 미리보기 데이터 (홈 화면용)
class CoachingPreview {
  final String id;
  final String message;
  final DateTime timestamp;

  const CoachingPreview({
    required this.id,
    required this.message,
    required this.timestamp,
  });
}

/// 홈 화면 전체 상태
class HomeState {
  final String nickname;
  final bool hasPlan;
  final TodaySession? todaySession;
  final WeeklyProgress? weeklyProgress;
  final CoachingPreview? latestCoaching;
  final List<WorkoutLog> recentWorkouts;

  const HomeState({
    this.nickname = '',
    this.hasPlan = false,
    this.todaySession,
    this.weeklyProgress,
    this.latestCoaching,
    this.recentWorkouts = const [],
  });
}

// ─── Providers ───

/// 홈 화면 상태 Provider (실제 데이터 연동)
final homeStateProvider = FutureProvider<HomeState>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const HomeState(nickname: '러너');
  }

  // 사용자 프로필 닉네임 가져오기
  final userRepo = ref.watch(userRepositoryProvider);
  String nickname = '러너';
  try {
    final profile = await userRepo.getProfile(user.id);
    if (profile != null) {
      nickname = profile.nickname;
    }
  } catch (_) {
    // 프로필 로드 실패 시 기본값 사용
  }

  // 활성 플랜 확인
  final plan = await ref.watch(activePlanProvider.future);
  final hasPlan = plan != null;

  // 오늘의 훈련 세션
  TodaySession? todaySession;
  if (hasPlan) {
    final todaySessions = await ref.watch(todaySessionsProvider.future);
    if (todaySessions.isNotEmpty) {
      // 첫 번째 훈련 세션 (rest 제외)
      final session = todaySessions.firstWhere(
        (s) => s.sessionType != 'rest',
        orElse: () => todaySessions.first,
      );

      final zoneType = trainingZoneTypeFromDbString(session.sessionType);
      final isCompleted = session.status == 'completed';

      // 완료된 경우 연결된 workout_log 조회
      WorkoutLog? linkedWorkout;
      if (isCompleted) {
        try {
          final workoutRepo = ref.watch(workoutRepositoryProvider);
          linkedWorkout =
              await workoutRepo.getWorkoutBySessionId(session.id);
        } catch (_) {
          // workout log 조회 실패 시 무시
        }
      }

      todaySession = TodaySession(
        id: session.id,
        zoneType: zoneType,
        title: session.title,
        targetPace: session.targetPace,
        estimatedTime: session.targetDurationMinutes != null
            ? '${session.targetDurationMinutes}분'
            : null,
        distanceKm: session.targetDistanceKm,
        description: session.description,
        isCompleted: isCompleted,
        workoutLog: linkedWorkout,
      );
    }
  }

  // 주간 진행률 (실제 데이터)
  WeeklyProgress? weeklyProgress;
  if (hasPlan) {
    weeklyProgress = await _calculateWeeklyProgress(ref, plan.id);
  }

  // 최근 코칭 메시지 (활성 플랜 기준)
  CoachingPreview? latestCoaching;
  if (hasPlan) {
    try {
      final coachingMessages =
          await ref.watch(planCoachingMessagesProvider.future);
      if (coachingMessages.isNotEmpty) {
        final latest = coachingMessages.first;
        latestCoaching = CoachingPreview(
          id: latest.id,
          message: latest.content,
          timestamp: latest.createdAt,
        );
      }
    } catch (_) {
      // 코칭 메시지 조회 실패 시 무시
    }
  }

  // 최근 운동 기록
  List<WorkoutLog> recentWorkouts = [];
  try {
    recentWorkouts = await ref.watch(recentWorkoutLogsProvider.future);
  } catch (_) {
    // 운동 기록 조회 실패 시 빈 리스트
  }

  return HomeState(
    nickname: nickname,
    hasPlan: hasPlan,
    todaySession: todaySession,
    weeklyProgress: weeklyProgress,
    latestCoaching: latestCoaching,
    recentWorkouts: recentWorkouts,
  );
});

/// 주간 진행률 계산 (현재 주차 기반)
Future<WeeklyProgress?> _calculateWeeklyProgress(
  Ref ref,
  String planId,
) async {
  try {
    final currentWeek = await ref.watch(dbCurrentWeekProvider.future);
    if (currentWeek == null) return null;

    final sessions =
        await ref.watch(dbWeekSessionsProvider(currentWeek.id).future);
    if (sessions.isEmpty) return null;

    // rest 제외 훈련 세션만
    final trainingSessions =
        sessions.where((s) => s.sessionType != 'rest').toList();

    // 완료된 세션 수
    final completedSessions =
        trainingSessions.where((s) => s.status == 'completed').length;

    // 목표 거리 합
    final totalKm = trainingSessions.fold<double>(
      0.0,
      (sum, s) => sum + (s.targetDistanceKm ?? 0.0),
    );

    // 완료된 세션의 거리 합
    // 실제 workout_log가 있으면 실제 거리 사용, 없으면 목표 거리 사용
    double completedKm = 0.0;
    final workoutRepo = ref.watch(workoutRepositoryProvider);
    for (final session in trainingSessions) {
      if (session.status == 'completed') {
        try {
          final workout =
              await workoutRepo.getWorkoutBySessionId(session.id);
          if (workout != null) {
            completedKm += workout.distanceKm;
          } else {
            completedKm += session.targetDistanceKm ?? 0.0;
          }
        } catch (_) {
          completedKm += session.targetDistanceKm ?? 0.0;
        }
      }
    }

    return WeeklyProgress(
      completedSessions: completedSessions,
      totalSessions: trainingSessions.length,
      completedKm: completedKm,
      totalKm: totalKm,
    );
  } catch (_) {
    return null;
  }
}

/// 활성 플랜 존재 여부
final hasActivePlanProvider = Provider<bool>((ref) {
  final homeState = ref.watch(homeStateProvider);
  return homeState.valueOrNull?.hasPlan ?? false;
});
