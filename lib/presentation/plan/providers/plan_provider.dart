import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/training_zones.dart';
import '../../../data/models/training_plan.dart' as db;
import '../../../data/models/training_session.dart';
import '../../../data/repositories/plan_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../common/widgets/training_session_card.dart';
import '../../providers/data_providers.dart';

// ─── UI View Models ───

/// 주차 데이터 (UI 뷰모델)
class WeekData {
  final String id;
  final int weekNumber;
  final String phase;
  final DateTime startDate;
  final DateTime endDate;
  final double targetKm;
  final double completedKm;
  final List<DaySession> sessions;

  const WeekData({
    required this.id,
    required this.weekNumber,
    required this.phase,
    required this.startDate,
    required this.endDate,
    required this.targetKm,
    required this.completedKm,
    required this.sessions,
  });

  String get phaseLabel {
    switch (phase) {
      case 'base':
        return '기초';
      case 'build':
        return '빌드';
      case 'peak':
        return '피크';
      case 'taper':
        return '테이퍼';
      default:
        return phase;
    }
  }

  double get progress => targetKm > 0 ? completedKm / targetKm : 0.0;
}

/// 일별 훈련 세션 데이터 (UI 뷰모델)
class DaySession {
  final String id;
  final int dayOfWeek;
  final TrainingZoneType zoneType;
  final String title;
  final double? distanceKm;
  final String? targetPace;
  final String? estimatedTime;
  final SessionStatus status;
  final String? description;
  final Map<String, dynamic>? workoutDetail;

  const DaySession({
    required this.id,
    required this.dayOfWeek,
    required this.zoneType,
    required this.title,
    this.distanceKm,
    this.targetPace,
    this.estimatedTime,
    this.status = SessionStatus.pending,
    this.description,
    this.workoutDetail,
  });

  String get dayLabel {
    switch (dayOfWeek) {
      case 1:
        return '월';
      case 2:
        return '화';
      case 3:
        return '수';
      case 4:
        return '목';
      case 5:
        return '금';
      case 6:
        return '토';
      case 7:
        return '일';
      default:
        return '';
    }
  }
}

// ─── 플랜 화면 상태 ───

class PlanScreenState {
  final db.TrainingPlan? activePlan;
  final int currentWeekIndex;
  final List<WeekData> weeks;
  final bool isLoading;
  final String? error;

  const PlanScreenState({
    this.activePlan,
    this.currentWeekIndex = 0,
    this.weeks = const [],
    this.isLoading = false,
    this.error,
  });

  WeekData? get currentWeek =>
      weeks.isNotEmpty && currentWeekIndex < weeks.length
          ? weeks[currentWeekIndex]
          : null;

  bool get hasPlan => activePlan != null;

  PlanScreenState copyWith({
    db.TrainingPlan? activePlan,
    int? currentWeekIndex,
    List<WeekData>? weeks,
    bool? isLoading,
    String? error,
  }) =>
      PlanScreenState(
        activePlan: activePlan ?? this.activePlan,
        currentWeekIndex: currentWeekIndex ?? this.currentWeekIndex,
        weeks: weeks ?? this.weeks,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ─── Notifier ───

class PlanNotifier extends StateNotifier<PlanScreenState> {
  final PlanRepository _planRepo;
  final String? _userId;

  PlanNotifier({
    required PlanRepository planRepo,
    required String? userId,
  })  : _planRepo = planRepo,
        _userId = userId,
        super(const PlanScreenState(isLoading: true)) {
    _loadRealData();
  }

  Future<void> _loadRealData() async {
    if (_userId == null) {
      state = const PlanScreenState(isLoading: false);
      return;
    }

    try {
      // 활성 플랜 조회
      final plan = await _planRepo.getActivePlan(_userId);
      if (plan == null) {
        state = const PlanScreenState(isLoading: false);
        return;
      }

      // 주차 목록 조회
      final dbWeeks = await _planRepo.getWeeksByPlan(plan.id);

      // 현재 주차 인덱스 계산 (날짜 기반)
      final today = DateTime.now();
      int currentWeekIdx = 0; // 기본값: 첫 주차
      for (int i = 0; i < dbWeeks.length; i++) {
        if (!today.isBefore(dbWeeks[i].startDate) &&
            !today.isAfter(dbWeeks[i].endDate.add(const Duration(days: 1)))) {
          currentWeekIdx = i;
          break;
        }
      }
      // 모든 주차가 지난 경우에만 마지막 주차 선택
      if (dbWeeks.isNotEmpty && today.isAfter(dbWeeks.last.endDate)) {
        currentWeekIdx = dbWeeks.length - 1;
      }

      // 각 주차의 세션을 로드하여 WeekData로 변환
      final weeks = <WeekData>[];
      for (final dbWeek in dbWeeks) {
        final dbSessions = await _planRepo.getSessionsByWeek(dbWeek.id);
        final sessions = dbSessions.map(_convertSession).toList();

        // 완료된 세션의 거리 합산
        double completedKm = 0;
        for (final s in dbSessions) {
          if (s.status == 'completed') {
            completedKm += s.targetDistanceKm ?? 0.0;
          }
        }

        weeks.add(WeekData(
          id: dbWeek.id,
          weekNumber: dbWeek.weekNumber,
          phase: dbWeek.phase,
          startDate: dbWeek.startDate,
          endDate: dbWeek.endDate,
          targetKm: dbWeek.targetDistanceKm ?? 0,
          completedKm: completedKm,
          sessions: sessions,
        ));
      }

      state = PlanScreenState(
        activePlan: plan,
        currentWeekIndex: currentWeekIdx,
        weeks: weeks,
        isLoading: false,
      );
    } catch (e) {
      state = const PlanScreenState(
        isLoading: false,
        error: '플랜을 불러오는데 실패했습니다',
      );
    }
  }

  /// DB TrainingSession → UI DaySession 변환
  DaySession _convertSession(TrainingSession s) {
    final zoneType = trainingZoneTypeFromDbString(s.sessionType);
    final status = _convertStatus(s.status);

    return DaySession(
      id: s.id,
      dayOfWeek: s.dayOfWeek,
      zoneType: zoneType,
      title: s.title,
      distanceKm: s.targetDistanceKm,
      targetPace: s.targetPace,
      estimatedTime: s.targetDurationMinutes != null
          ? '${s.targetDurationMinutes}분'
          : null,
      status: status,
      description: s.description,
      workoutDetail: s.workoutDetail,
    );
  }

  SessionStatus _convertStatus(String dbStatus) {
    switch (dbStatus) {
      case 'completed':
        return SessionStatus.completed;
      case 'missed':
        return SessionStatus.missed;
      case 'skipped':
        return SessionStatus.skipped;
      case 'partial':
        return SessionStatus.partial;
      case 'rest':
        return SessionStatus.rest;
      default:
        return SessionStatus.pending;
    }
  }

  /// 활성 플랜 전환 (다른 플랜을 active로 설정)
  Future<void> switchActivePlan(String newPlanId) async {
    final currentPlan = state.activePlan;
    if (currentPlan == null || currentPlan.id == newPlanId) return;

    state = state.copyWith(isLoading: true);
    try {
      // 1) 현재 active 플랜 → upcoming (비활성화 먼저)
      await _planRepo.updatePlanStatus(currentPlan.id, 'upcoming');
      // 2) 선택된 플랜 → active
      await _planRepo.updatePlanStatus(newPlanId, 'active');
      // 3) 새 플랜 데이터 로드
      await _loadRealData();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '플랜 전환에 실패했습니다',
      );
    }
  }

  /// 데이터 새로고침
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadRealData();
  }

  void goToPreviousWeek() {
    if (state.currentWeekIndex > 0) {
      state = state.copyWith(currentWeekIndex: state.currentWeekIndex - 1);
    }
  }

  void goToNextWeek() {
    if (state.currentWeekIndex < state.weeks.length - 1) {
      state = state.copyWith(currentWeekIndex: state.currentWeekIndex + 1);
    }
  }

  void goToWeek(int index) {
    if (index >= 0 && index < state.weeks.length) {
      state = state.copyWith(currentWeekIndex: index);
    }
  }
}

// ─── Providers ───

final planProvider =
    StateNotifierProvider<PlanNotifier, PlanScreenState>((ref) {
  return PlanNotifier(
    planRepo: ref.watch(planRepositoryProvider),
    userId: ref.watch(currentUserProvider)?.id,
  );
});

/// 현재 주차 Provider (편의)
final currentWeekProvider = Provider<WeekData?>((ref) {
  return ref.watch(planProvider).currentWeek;
});

/// 현재 주차 세션 목록 Provider
final weekSessionsProvider = Provider<List<DaySession>>((ref) {
  return ref.watch(currentWeekProvider)?.sessions ?? [];
});

/// 세션 ID로 세션 찾기 Provider
final sessionByIdProvider =
    Provider.family<DaySession?, String>((ref, sessionId) {
  final planState = ref.watch(planProvider);
  for (final week in planState.weeks) {
    for (final session in week.sessions) {
      if (session.id == sessionId) return session;
    }
  }
  return null;
});

/// 세션이 속한 주차 번호 Provider
final sessionWeekNumberProvider =
    Provider.family<int?, String>((ref, sessionId) {
  final planState = ref.watch(planProvider);
  for (final week in planState.weeks) {
    for (final session in week.sessions) {
      if (session.id == sessionId) return week.weekNumber;
    }
  }
  return null;
});
