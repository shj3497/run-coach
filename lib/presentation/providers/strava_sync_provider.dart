import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/providers/auth_providers.dart';
import '../home/providers/home_provider.dart';
import '../plan/providers/plan_provider.dart';
import 'data_providers.dart';
import 'strava_auth_provider.dart';

// ─── State ───

enum StravaSyncStatus { idle, syncing, success, error }

class StravaSyncState {
  final StravaSyncStatus status;
  final DateTime? lastSyncAt;
  final int newWorkoutsCount;
  final String? errorMessage;

  const StravaSyncState({
    this.status = StravaSyncStatus.idle,
    this.lastSyncAt,
    this.newWorkoutsCount = 0,
    this.errorMessage,
  });

  bool get isSyncing => status == StravaSyncStatus.syncing;

  StravaSyncState copyWith({
    StravaSyncStatus? status,
    DateTime? lastSyncAt,
    int? newWorkoutsCount,
    String? errorMessage,
  }) =>
      StravaSyncState(
        status: status ?? this.status,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        newWorkoutsCount: newWorkoutsCount ?? this.newWorkoutsCount,
        errorMessage: errorMessage,
      );
}

// ─── Notifier ───

class StravaSyncNotifier extends StateNotifier<StravaSyncState> {
  final Ref _ref;
  final String? _userId;

  static const _syncDebounce = Duration(minutes: 5);

  StravaSyncNotifier({
    required Ref ref,
    required String? userId,
  })  : _ref = ref,
        _userId = userId,
        super(const StravaSyncState());

  /// 필요 시 동기화 (5분 디바운스)
  Future<void> syncIfNeeded() async {
    if (_userId == null) return;
    if (state.isSyncing) return;

    // Strava 연결 확인
    final authState = _ref.read(stravaAuthProvider);
    if (!authState.isConnected) return;

    // 5분 내 동기화 했으면 스킵
    if (state.lastSyncAt != null) {
      final elapsed = DateTime.now().difference(state.lastSyncAt!);
      if (elapsed < _syncDebounce) return;
    }

    await _doSync();
  }

  /// 디바운스 무시하고 즉시 동기화
  Future<void> forceSync() async {
    debugPrint('[StravaSync] forceSync() called — userId=$_userId');
    if (_userId == null) {
      debugPrint('[StravaSync] SKIP: userId is null');
      return;
    }
    if (state.isSyncing) {
      debugPrint('[StravaSync] SKIP: already syncing');
      return;
    }

    final authState = _ref.read(stravaAuthProvider);
    debugPrint(
        '[StravaSync] authState: status=${authState.status}, isConnected=${authState.isConnected}');
    if (!authState.isConnected) {
      debugPrint('[StravaSync] SKIP: Strava not connected');
      return;
    }

    debugPrint('[StravaSync] Starting _doSync()...');
    await _doSync();
  }

  Future<void> _doSync() async {
    state = state.copyWith(status: StravaSyncStatus.syncing);

    try {
      final stravaService = _ref.read(stravaServiceProvider);
      final processUseCase = _ref.read(processWorkoutUseCaseProvider);

      // 새 Activity 가져오기
      debugPrint('[StravaSync] Fetching new activities for $_userId');
      final newWorkouts = await stravaService.getNewActivitiesSince(
        userId: _userId!,
      );
      debugPrint('[StravaSync] Found ${newWorkouts.length} new activities');

      if (newWorkouts.isEmpty) {
        debugPrint('[StravaSync] No new activities — skipping markSyncComplete');
        state = StravaSyncState(
          status: StravaSyncStatus.success,
          lastSyncAt: DateTime.now(),
          newWorkoutsCount: 0,
        );
        return;
      }

      // 일괄 처리 (저장 + 세션 매칭)
      debugPrint('[StravaSync] Processing ${newWorkouts.length} workouts...');
      final result = await processUseCase.executeBatch(
        workoutLogs: newWorkouts,
        userId: _userId,
      );
      debugPrint(
          '[StravaSync] Done: ${result.newWorkoutCount} new workouts saved');

      // 저장 성공 후에만 last_sync_at 업데이트
      await stravaService.markSyncComplete(_userId);

      state = StravaSyncState(
        status: StravaSyncStatus.success,
        lastSyncAt: DateTime.now(),
        newWorkoutsCount: result.newWorkoutCount,
      );

      // 관련 provider 무효화
      _invalidateProviders();
    } catch (e, stackTrace) {
      debugPrint('[StravaSync] ERROR: $e');
      debugPrint('[StravaSync] StackTrace: $stackTrace');
      state = state.copyWith(
        status: StravaSyncStatus.error,
        errorMessage: '동기화에 실패했습니다: $e',
      );
    }
  }

  /// 동기화 후 관련 provider 무효화
  void _invalidateProviders() {
    _ref.invalidate(recentWorkoutLogsProvider);
    _ref.invalidate(thisWeekWorkoutLogsProvider);
    _ref.invalidate(homeStateProvider);
    // 플랜 세션 상태 갱신 (매칭된 workout → 세션 completed 반영)
    _ref.read(planProvider.notifier).refresh();
    _ref.invalidate(activePlanProvider);
    _ref.invalidate(todaySessionsProvider);
  }
}

// ─── Providers ───

final stravaSyncProvider =
    StateNotifierProvider<StravaSyncNotifier, StravaSyncState>((ref) {
  return StravaSyncNotifier(
    ref: ref,
    userId: ref.watch(currentUserProvider)?.id,
  );
});
