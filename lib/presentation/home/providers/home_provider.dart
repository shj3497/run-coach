import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/training_zones.dart';

// ─── Mock Data Models (Phase 3: Repository 완성 전까지 사용) ───

/// 오늘의 훈련 세션 데이터
class TodaySession {
  final String id;
  final TrainingZoneType zoneType;
  final String title;
  final String? targetPace;
  final String? estimatedTime;
  final double? distanceKm;
  final String? description;

  const TodaySession({
    required this.id,
    required this.zoneType,
    required this.title,
    this.targetPace,
    this.estimatedTime,
    this.distanceKm,
    this.description,
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

  const HomeState({
    this.nickname = '',
    this.hasPlan = false,
    this.todaySession,
    this.weeklyProgress,
    this.latestCoaching,
  });
}

// ─── Providers ───

/// 홈 화면 상태 Provider (mock 데이터)
final homeStateProvider = FutureProvider<HomeState>((ref) async {
  // Phase 3: Repository 완성 전까지 mock 데이터 반환
  return HomeState(
    nickname: '러너',
    hasPlan: true,
    todaySession: const TodaySession(
      id: 'w3-5', // plan_provider.dart의 3주차 금요일 세션과 일치
      zoneType: TrainingZoneType.threshold,
      title: '템포런 6km',
      targetPace: '5:00-5:10',
      estimatedTime: '30-31분',
      distanceKm: 6.0,
      description: '젖산 역치 페이스로 달리세요. "편안하게 힘든" 정도의 강도를 유지하세요.',
    ),
    weeklyProgress: const WeeklyProgress(
      completedSessions: 3,
      totalSessions: 5,
      completedKm: 24,
      totalKm: 40,
    ),
    latestCoaching: CoachingPreview(
      id: 'mock-coaching-1',
      message: '이번 주 이지런 페이스를 잘 유지하고 있어요. 내일 인터벌 훈련 전에 충분히 쉬어주세요.',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  );
});

/// 활성 플랜 존재 여부
final hasActivePlanProvider = Provider<bool>((ref) {
  final homeState = ref.watch(homeStateProvider);
  return homeState.valueOrNull?.hasPlan ?? false;
});
