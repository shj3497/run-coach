import '../../data/models/training_session.dart';
import '../../data/models/workout_log.dart';
import '../../data/repositories/plan_repository.dart';
import '../../data/repositories/workout_repository.dart';
import 'match_workout_to_session.dart';

/// 워크아웃 데이터 처리 파이프라인
///
/// HealthKit/Strava에서 수신된 운동 데이터를 처리하는 전체 파이프라인:
/// 1. 중복 체크 (external_id 기반)
/// 2. WorkoutLog 저장
/// 3. 활성 플랜 확인
/// 4. 매칭 로직 실행
/// 5. 매칭 성공 시 세션 상태 업데이트
/// 6. 결과 반환
class ProcessWorkoutUseCase {
  final WorkoutRepository _workoutRepository;
  final PlanRepository _planRepository;
  final MatchWorkoutToSession _matchUseCase;

  const ProcessWorkoutUseCase({
    required WorkoutRepository workoutRepository,
    required PlanRepository planRepository,
    MatchWorkoutToSession matchUseCase = const MatchWorkoutToSession(),
  })  : _workoutRepository = workoutRepository,
        _planRepository = planRepository,
        _matchUseCase = matchUseCase;

  /// 단일 워크아웃 처리
  ///
  /// [workoutLog] 처리할 운동 기록 (아직 DB에 저장되지 않은 상태)
  /// [userId] 사용자 ID
  ///
  /// 반환: [ProcessWorkoutResult] 처리 결과
  Future<ProcessWorkoutResult> execute({
    required WorkoutLog workoutLog,
    required String userId,
  }) async {
    // 1. 중복 체크 (external_id가 있는 경우)
    if (workoutLog.externalId != null && workoutLog.externalId!.isNotEmpty) {
      final existing = await _workoutRepository.getWorkoutByExternalId(
        userId,
        workoutLog.source,
        workoutLog.externalId!,
      );

      if (existing != null) {
        return ProcessWorkoutResult(
          savedWorkout: existing,
          matchedSession: null,
          matchStatus: 'duplicate',
          matchScore: null,
          isDuplicate: true,
        );
      }
    }

    // 2. WorkoutLog 저장
    final savedWorkout = await _workoutRepository.createWorkoutLog(workoutLog);

    // 3. 활성 플랜 확인
    final activePlan = await _planRepository.getActivePlan(userId);

    if (activePlan == null) {
      // 활성 플랜이 없으면 자유 운동으로 처리
      return ProcessWorkoutResult(
        savedWorkout: savedWorkout,
        matchedSession: null,
        matchStatus: 'unmatched',
        matchScore: null,
        isDuplicate: false,
      );
    }

    // 4. 매칭 후보 세션 조회 (운동 날짜 기준 +/- 2일 범위)
    final searchStartDate =
        savedWorkout.workoutDate.subtract(const Duration(days: 2));
    final searchEndDate =
        savedWorkout.workoutDate.add(const Duration(days: 2));

    final candidateSessions = await _planRepository.getSessionsByDateRange(
      activePlan.id,
      searchStartDate,
      searchEndDate,
    );

    // pending 세션만 필터링
    final pendingSessions = candidateSessions
        .where((s) => s.status == 'pending')
        .toList();

    // 5. 매칭 로직 실행
    final matchResult = _matchUseCase.execute(
      workout: savedWorkout,
      pendingSessions: pendingSessions,
    );

    if (matchResult == null) {
      // 매칭 실패: 자유 운동
      return ProcessWorkoutResult(
        savedWorkout: savedWorkout,
        matchedSession: null,
        matchStatus: 'unmatched',
        matchScore: null,
        isDuplicate: false,
      );
    }

    // 6. 매칭 성공: 세션 상태 업데이트
    final completionStatus = matchResult.determineCompletionStatus(
      savedWorkout.distanceKm,
    );

    // 6a. workout_log에 session_id 연결
    await _workoutRepository.linkWorkoutToSession(
      savedWorkout.id,
      matchResult.session.id,
    );

    // 6b. training_session 상태 업데이트
    if (completionStatus == 'completed' || completionStatus == 'partial') {
      await _planRepository.updateSessionStatus(
        matchResult.session.id,
        completionStatus,
        completedAt: savedWorkout.endedAt,
      );
    }
    // completionStatus == 'pending'이면 (50% 미만 달성) 세션 상태를 변경하지 않음

    return ProcessWorkoutResult(
      savedWorkout: savedWorkout,
      matchedSession: matchResult.session,
      matchStatus: completionStatus,
      matchScore: matchResult.score.totalScore,
      isDuplicate: false,
    );
  }

  /// 여러 워크아웃 일괄 처리
  ///
  /// HealthKit/Strava에서 동기화된 여러 운동 기록을 한번에 처리합니다.
  ///
  /// [workoutLogs] 처리할 운동 기록 목록
  /// [userId] 사용자 ID
  ///
  /// 반환: [BatchProcessResult] 일괄 처리 결과
  Future<BatchProcessResult> executeBatch({
    required List<WorkoutLog> workoutLogs,
    required String userId,
  }) async {
    if (workoutLogs.isEmpty) {
      return const BatchProcessResult(results: []);
    }

    // 중복 체크 및 저장을 먼저 수행
    final savedWorkouts = <WorkoutLog>[];
    final duplicates = <ProcessWorkoutResult>[];

    for (final log in workoutLogs) {
      // 중복 체크
      if (log.externalId != null && log.externalId!.isNotEmpty) {
        final existing = await _workoutRepository.getWorkoutByExternalId(
          userId,
          log.source,
          log.externalId!,
        );

        if (existing != null) {
          duplicates.add(ProcessWorkoutResult(
            savedWorkout: existing,
            matchedSession: null,
            matchStatus: 'duplicate',
            matchScore: null,
            isDuplicate: true,
          ));
          continue;
        }
      }

      // 저장
      final saved = await _workoutRepository.createWorkoutLog(log);
      savedWorkouts.add(saved);
    }

    // 활성 플랜 확인
    final activePlan = await _planRepository.getActivePlan(userId);

    if (activePlan == null) {
      // 활성 플랜 없으면 모든 워크아웃을 자유 운동으로 처리
      final results = <ProcessWorkoutResult>[
        ...duplicates,
        ...savedWorkouts.map((w) => ProcessWorkoutResult(
              savedWorkout: w,
              matchedSession: null,
              matchStatus: 'unmatched',
              matchScore: null,
              isDuplicate: false,
            )),
      ];
      return BatchProcessResult(results: results);
    }

    // 날짜 범위 계산 (전체 워크아웃의 최소/최대 날짜 + 여유)
    if (savedWorkouts.isEmpty) {
      return BatchProcessResult(results: duplicates);
    }

    final allDates = savedWorkouts.map((w) => w.workoutDate).toList();
    allDates.sort();
    final searchStartDate = allDates.first.subtract(const Duration(days: 2));
    final searchEndDate = allDates.last.add(const Duration(days: 2));

    // 매칭 후보 세션 한번에 조회
    final candidateSessions = await _planRepository.getSessionsByDateRange(
      activePlan.id,
      searchStartDate,
      searchEndDate,
    );

    final pendingSessions = candidateSessions
        .where((s) => s.status == 'pending')
        .toList();

    // 일괄 매칭
    final batchMatchResult = _matchUseCase.syncAndMatchWorkouts(
      workouts: savedWorkouts,
      pendingSessions: pendingSessions,
    );

    // 매칭 결과 처리
    final matchedResults = <ProcessWorkoutResult>[];

    for (final pair in batchMatchResult.matchedPairs) {
      final completionStatus = pair.completionStatus;

      // workout_log에 session_id 연결
      await _workoutRepository.linkWorkoutToSession(
        pair.workout.id,
        pair.session.id,
      );

      // training_session 상태 업데이트
      if (completionStatus == 'completed' || completionStatus == 'partial') {
        await _planRepository.updateSessionStatus(
          pair.session.id,
          completionStatus,
          completedAt: pair.workout.endedAt,
        );
      }

      matchedResults.add(ProcessWorkoutResult(
        savedWorkout: pair.workout,
        matchedSession: pair.session,
        matchStatus: completionStatus,
        matchScore: pair.score.totalScore,
        isDuplicate: false,
      ));
    }

    // 매칭 실패 워크아웃
    final unmatchedResults = batchMatchResult.unmatchedWorkouts
        .map((w) => ProcessWorkoutResult(
              savedWorkout: w,
              matchedSession: null,
              matchStatus: 'unmatched',
              matchScore: null,
              isDuplicate: false,
            ))
        .toList();

    return BatchProcessResult(
      results: [...duplicates, ...matchedResults, ...unmatchedResults],
    );
  }
}

// =============================================================================
// 결과 모델
// =============================================================================

/// 단일 워크아웃 처리 결과
class ProcessWorkoutResult {
  /// 저장된 운동 기록
  final WorkoutLog savedWorkout;

  /// 매칭된 훈련 세션 (없으면 null - 자유 운동 또는 매칭 실패)
  final TrainingSession? matchedSession;

  /// 매칭 상태
  /// - 'completed': 목표 80% 이상 달성
  /// - 'partial': 목표 50~80% 달성
  /// - 'pending': 50% 미만 달성 (세션 상태 변경 없음)
  /// - 'unmatched': 매칭 실패 (자유 운동)
  /// - 'duplicate': 이미 저장된 중복 기록
  final String? matchStatus;

  /// 매칭 점수 (0.0~1.0, 매칭 실패 시 null)
  final double? matchScore;

  /// 중복 기록 여부
  final bool isDuplicate;

  const ProcessWorkoutResult({
    required this.savedWorkout,
    required this.matchedSession,
    required this.matchStatus,
    required this.matchScore,
    required this.isDuplicate,
  });

  /// 매칭 성공 여부
  bool get isMatched =>
      matchedSession != null && matchStatus != 'unmatched';

  /// 완전 완료 여부
  bool get isCompleted => matchStatus == 'completed';

  /// 부분 완료 여부
  bool get isPartial => matchStatus == 'partial';

  @override
  String toString() =>
      'ProcessWorkoutResult('
      'status: $matchStatus, '
      'score: ${matchScore?.toStringAsFixed(2) ?? "null"}, '
      'duplicate: $isDuplicate, '
      'session: ${matchedSession?.id ?? "null"}'
      ')';
}

/// 일괄 처리 결과
class BatchProcessResult {
  /// 개별 처리 결과 목록
  final List<ProcessWorkoutResult> results;

  const BatchProcessResult({required this.results});

  /// 총 처리 수
  int get totalCount => results.length;

  /// 매칭 성공 수
  int get matchedCount => results.where((r) => r.isMatched).length;

  /// 매칭 실패 수 (자유 운동)
  int get unmatchedCount =>
      results.where((r) => r.matchStatus == 'unmatched').length;

  /// 중복 수
  int get duplicateCount => results.where((r) => r.isDuplicate).length;

  /// 완료 처리 수
  int get completedCount => results.where((r) => r.isCompleted).length;

  /// 부분 완료 수
  int get partialCount => results.where((r) => r.isPartial).length;

  /// 새로 저장된 운동 수 (중복 제외)
  int get newWorkoutCount => results.where((r) => !r.isDuplicate).length;

  @override
  String toString() =>
      'BatchProcessResult('
      'total: $totalCount, '
      'matched: $matchedCount, '
      'unmatched: $unmatchedCount, '
      'duplicates: $duplicateCount, '
      'completed: $completedCount, '
      'partial: $partialCount'
      ')';
}
