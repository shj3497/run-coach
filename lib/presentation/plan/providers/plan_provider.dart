import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/training_zones.dart';
import '../../common/widgets/training_session_card.dart';

// ─── Mock Data Models ───

/// 훈련 플랜 데이터
class TrainingPlan {
  final String id;
  final String name;
  final String status; // active, completed, cancelled
  final int totalWeeks;
  final double? goalDistanceKm;
  final int? goalTimeSeconds;
  final double? vdotAtCreation;
  final DateTime startDate;
  final DateTime endDate;
  final Map<TrainingZoneType, String>? paceZones;

  const TrainingPlan({
    required this.id,
    required this.name,
    required this.status,
    required this.totalWeeks,
    this.goalDistanceKm,
    this.goalTimeSeconds,
    this.vdotAtCreation,
    required this.startDate,
    required this.endDate,
    this.paceZones,
  });
}

/// 주차 데이터
class WeekData {
  final int weekNumber;
  final String phase; // base, build, peak, taper
  final DateTime startDate;
  final DateTime endDate;
  final double targetKm;
  final double completedKm;
  final List<DaySession> sessions;

  const WeekData({
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

/// 일별 훈련 세션 데이터
class DaySession {
  final String id;
  final int dayOfWeek; // 1=월 ~ 7=일
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
  final TrainingPlan? activePlan;
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
    TrainingPlan? activePlan,
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
  PlanNotifier() : super(const PlanScreenState(isLoading: true)) {
    _loadMockData();
  }

  void _loadMockData() {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));

    final mockPlan = TrainingPlan(
      id: 'mock-plan-1',
      name: '2026 서울마라톤 준비',
      status: 'active',
      totalWeeks: 12,
      goalDistanceKm: 42.195,
      goalTimeSeconds: 14400, // 4시간
      vdotAtCreation: 42.1,
      startDate: now.subtract(const Duration(days: 14)),
      endDate: now.add(const Duration(days: 70)),
      paceZones: {
        TrainingZoneType.easy: '6:00-6:30',
        TrainingZoneType.marathon: '5:30-5:45',
        TrainingZoneType.threshold: '5:00-5:10',
        TrainingZoneType.interval: '4:30-4:45',
        TrainingZoneType.repetition: '4:00-4:15',
      },
    );

    final mockWeeks = <WeekData>[
      // 1주차 (완료)
      WeekData(
        weekNumber: 1,
        phase: 'base',
        startDate: weekStart.subtract(const Duration(days: 14)),
        endDate: weekStart.subtract(const Duration(days: 8)),
        targetKm: 30,
        completedKm: 28,
        sessions: [
          const DaySession(
            id: 'w1-1', dayOfWeek: 1, zoneType: TrainingZoneType.easy,
            title: '이지런 6km', distanceKm: 6, targetPace: '6:00-6:30',
            estimatedTime: '36-39분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w1-2', dayOfWeek: 2, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
          const DaySession(
            id: 'w1-3', dayOfWeek: 3, zoneType: TrainingZoneType.threshold,
            title: '템포런 5km', distanceKm: 5, targetPace: '5:00-5:10',
            estimatedTime: '25-26분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w1-4', dayOfWeek: 4, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
          const DaySession(
            id: 'w1-5', dayOfWeek: 5, zoneType: TrainingZoneType.easy,
            title: '이지런 6km', distanceKm: 6, targetPace: '6:00-6:30',
            estimatedTime: '36-39분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w1-6', dayOfWeek: 6, zoneType: TrainingZoneType.longRun,
            title: '장거리런 12km', distanceKm: 12, targetPace: '6:00-6:30',
            estimatedTime: '72-78분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w1-7', dayOfWeek: 7, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
        ],
      ),
      // 2주차 (완료)
      WeekData(
        weekNumber: 2,
        phase: 'base',
        startDate: weekStart.subtract(const Duration(days: 7)),
        endDate: weekStart.subtract(const Duration(days: 1)),
        targetKm: 34,
        completedKm: 32,
        sessions: [
          const DaySession(
            id: 'w2-1', dayOfWeek: 1, zoneType: TrainingZoneType.easy,
            title: '이지런 7km', distanceKm: 7, targetPace: '6:00-6:30',
            estimatedTime: '42-46분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w2-2', dayOfWeek: 2, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
          const DaySession(
            id: 'w2-3', dayOfWeek: 3, zoneType: TrainingZoneType.interval,
            title: '인터벌 6x800m', distanceKm: 8, targetPace: '4:30-4:45',
            estimatedTime: '45-50분', status: SessionStatus.completed,
            workoutDetail: {
              'warmup': {'distance_km': 1.5, 'pace': '6:00-6:30'},
              'intervals': [
                {'reps': 6, 'distance_m': 800, 'pace': '4:30-4:45', 'rest_m': 400, 'rest_pace': '6:30-7:00'},
              ],
              'cooldown': {'distance_km': 1.5, 'pace': '6:00-6:30'},
            },
          ),
          const DaySession(
            id: 'w2-4', dayOfWeek: 4, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
          const DaySession(
            id: 'w2-5', dayOfWeek: 5, zoneType: TrainingZoneType.easy,
            title: '이지런 7km', distanceKm: 7, targetPace: '6:00-6:30',
            estimatedTime: '42-46분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w2-6', dayOfWeek: 6, zoneType: TrainingZoneType.longRun,
            title: '장거리런 14km', distanceKm: 14, targetPace: '6:00-6:30',
            estimatedTime: '84-91분', status: SessionStatus.missed,
          ),
          const DaySession(
            id: 'w2-7', dayOfWeek: 7, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
        ],
      ),
      // 3주차 (현재)
      WeekData(
        weekNumber: 3,
        phase: 'build',
        startDate: weekStart,
        endDate: weekStart.add(const Duration(days: 6)),
        targetKm: 38,
        completedKm: 16,
        sessions: [
          const DaySession(
            id: 'w3-1', dayOfWeek: 1, zoneType: TrainingZoneType.easy,
            title: '이지런 8km', distanceKm: 8, targetPace: '6:00-6:30',
            estimatedTime: '48-52분', status: SessionStatus.completed,
          ),
          const DaySession(
            id: 'w3-2', dayOfWeek: 2, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
          const DaySession(
            id: 'w3-3', dayOfWeek: 3, zoneType: TrainingZoneType.interval,
            title: '인터벌 6x800m', distanceKm: 8, targetPace: '4:30-4:45',
            estimatedTime: '45-50분', status: SessionStatus.completed,
            workoutDetail: {
              'warmup': {'distance_km': 1.5, 'pace': '6:00-6:30'},
              'intervals': [
                {'reps': 6, 'distance_m': 800, 'pace': '4:30-4:45', 'rest_m': 400, 'rest_pace': '6:30-7:00'},
              ],
              'cooldown': {'distance_km': 1.5, 'pace': '6:00-6:30'},
            },
          ),
          const DaySession(
            id: 'w3-4', dayOfWeek: 4, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
          const DaySession(
            id: 'w3-5', dayOfWeek: 5, zoneType: TrainingZoneType.threshold,
            title: '템포런 6km', distanceKm: 6, targetPace: '5:00-5:10',
            estimatedTime: '30-31분', status: SessionStatus.pending,
          ),
          const DaySession(
            id: 'w3-6', dayOfWeek: 6, zoneType: TrainingZoneType.longRun,
            title: '장거리런 16km', distanceKm: 16, targetPace: '6:00-6:30',
            estimatedTime: '96-104분', status: SessionStatus.pending,
          ),
          const DaySession(
            id: 'w3-7', dayOfWeek: 7, zoneType: TrainingZoneType.rest,
            title: '휴식', status: SessionStatus.rest,
          ),
        ],
      ),
    ];

    state = PlanScreenState(
      activePlan: mockPlan,
      currentWeekIndex: 2, // 현재 3주차
      weeks: mockWeeks,
      isLoading: false,
    );
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
  return PlanNotifier();
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
