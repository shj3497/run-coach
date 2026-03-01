import '../../data/models/training_session.dart';
import '../../data/models/workout_log.dart';

/// 운동 기록을 훈련 세션에 매칭하는 유스케이스
///
/// HealthKit/Strava에서 가져온 실제 운동 기록을
/// 활성 훈련 플랜의 세션에 자동 매칭합니다.
///
/// 매칭 기준 (가중치):
/// 1. 날짜 일치 (50%) - 같은 날 1.0, +/-1일 0.5, +/-2일 0.2
/// 2. 거리 유사도 (30%) - 목표 대비 실제 거리 비율
/// 3. 훈련 유형 패턴 (15%) - session_type과 운동 패턴 매칭
/// 4. 시간대 (5%) - 세션 예정 시간대와 실제 운동 시간대
class MatchWorkoutToSession {
  const MatchWorkoutToSession();

  // -------------------------------------------------------------------------
  // 가중치 상수
  // -------------------------------------------------------------------------
  static const double _dateWeight = 0.50;
  static const double _distanceWeight = 0.30;
  static const double _typeWeight = 0.15;
  static const double _timeOfDayWeight = 0.05;

  /// 최소 매칭 점수 임계값
  static const double _minimumThreshold = 0.3;

  // -------------------------------------------------------------------------
  // 단일 워크아웃 매칭
  // -------------------------------------------------------------------------

  /// 운동 기록에 가장 적합한 훈련 세션을 매칭
  ///
  /// [workout] 매칭할 운동 기록
  /// [pendingSessions] 매칭 후보 세션 목록 (status: pending인 세션들)
  /// [excludeSessionIds] 이미 매칭된 세션 ID 목록 (중복 매칭 방지)
  ///
  /// 반환: 매칭된 세션과 매칭 점수. 적합한 세션이 없으면 null
  MatchResult? execute({
    required WorkoutLog workout,
    required List<TrainingSession> pendingSessions,
    Set<String>? excludeSessionIds,
  }) {
    if (pendingSessions.isEmpty) return null;

    // rest 세션 제외 + 이미 완료/매칭된 세션 제외
    final candidates = pendingSessions.where((s) {
      if (s.sessionType == 'rest') return false;
      if (s.status == 'completed') return false;
      if (excludeSessionIds != null && excludeSessionIds.contains(s.id)) {
        return false;
      }
      return true;
    }).toList();

    if (candidates.isEmpty) return null;

    MatchResult? bestMatch;

    for (final session in candidates) {
      final score = _calculateMatchScore(
        workout: workout,
        session: session,
      );

      if (score == null) continue;

      if (bestMatch == null || score.totalScore > bestMatch.score.totalScore) {
        bestMatch = MatchResult(session: session, score: score);
      }
    }

    // 최소 매칭 점수 기준
    if (bestMatch != null && bestMatch.score.totalScore < _minimumThreshold) {
      return null;
    }

    return bestMatch;
  }

  /// 기존 호환 메서드 - 단순 날짜/거리 기반 매칭
  ///
  /// [workoutDate] 운동 날짜
  /// [workoutDistanceKm] 운동 거리 (km)
  /// [pendingSessions] 매칭 후보 세션 목록
  MatchResult? executeSimple({
    required DateTime workoutDate,
    required double workoutDistanceKm,
    required List<TrainingSession> pendingSessions,
  }) {
    if (pendingSessions.isEmpty) return null;

    final candidates =
        pendingSessions.where((s) => s.sessionType != 'rest').toList();

    if (candidates.isEmpty) return null;

    MatchResult? bestMatch;

    for (final session in candidates) {
      final dateScore = _calculateDateScore(workoutDate, session.sessionDate);
      if (dateScore == null) continue;

      final distanceScore = _calculateDistanceScore(
        workoutDistanceKm,
        session.targetDistanceKm,
      );

      final score = MatchScore(
        dateScore: dateScore,
        distanceScore: distanceScore,
        typeScore: 0.5, // 중립
        timeOfDayScore: 0.5, // 중립
      );

      if (bestMatch == null || score.totalScore > bestMatch.score.totalScore) {
        bestMatch = MatchResult(session: session, score: score);
      }
    }

    if (bestMatch != null && bestMatch.score.totalScore < _minimumThreshold) {
      return null;
    }

    return bestMatch;
  }

  // -------------------------------------------------------------------------
  // 복수 워크아웃 일괄 매칭
  // -------------------------------------------------------------------------

  /// 여러 운동 기록을 한번에 매칭 처리
  ///
  /// 활성 플랜의 pending 세션들과 비교하여 각 운동에 가장 적합한 세션을 매칭합니다.
  /// 하나의 세션에 여러 운동이 매칭될 수 있는 경우, 가장 높은 점수의 운동만 매칭합니다.
  ///
  /// [workouts] 매칭할 운동 기록 목록
  /// [pendingSessions] 매칭 후보 세션 목록
  ///
  /// 반환: 매칭 결과 (매칭된 쌍 목록 + 매칭 실패 운동 목록)
  BatchMatchResult syncAndMatchWorkouts({
    required List<WorkoutLog> workouts,
    required List<TrainingSession> pendingSessions,
  }) {
    if (workouts.isEmpty) {
      return const BatchMatchResult(
        matchedPairs: [],
        unmatchedWorkouts: [],
      );
    }

    if (pendingSessions.isEmpty) {
      return BatchMatchResult(
        matchedPairs: [],
        unmatchedWorkouts: List.from(workouts),
      );
    }

    // 각 워크아웃에 대해 모든 세션과의 매칭 점수 계산
    final allCandidates = <_MatchCandidate>[];

    for (final workout in workouts) {
      for (final session in pendingSessions) {
        // rest, completed 세션 제외
        if (session.sessionType == 'rest') continue;
        if (session.status == 'completed') continue;

        final score = _calculateMatchScore(
          workout: workout,
          session: session,
        );

        if (score != null && score.totalScore >= _minimumThreshold) {
          allCandidates.add(_MatchCandidate(
            workout: workout,
            session: session,
            score: score,
          ));
        }
      }
    }

    // 점수 내림차순 정렬
    allCandidates.sort((a, b) => b.score.totalScore.compareTo(a.score.totalScore));

    // 탐욕적 매칭: 높은 점수부터 매칭하되, 이미 사용된 세션/워크아웃은 제외
    final usedWorkoutIds = <String>{};
    final usedSessionIds = <String>{};
    final matchedPairs = <MatchedPair>[];

    for (final candidate in allCandidates) {
      if (usedWorkoutIds.contains(candidate.workout.id)) continue;
      if (usedSessionIds.contains(candidate.session.id)) continue;

      usedWorkoutIds.add(candidate.workout.id);
      usedSessionIds.add(candidate.session.id);

      matchedPairs.add(MatchedPair(
        workout: candidate.workout,
        session: candidate.session,
        score: candidate.score,
      ));
    }

    // 매칭되지 않은 워크아웃 (자유 운동)
    final unmatchedWorkouts = workouts
        .where((w) => !usedWorkoutIds.contains(w.id))
        .toList();

    return BatchMatchResult(
      matchedPairs: matchedPairs,
      unmatchedWorkouts: unmatchedWorkouts,
    );
  }

  // -------------------------------------------------------------------------
  // 점수 계산 (private)
  // -------------------------------------------------------------------------

  /// 종합 매칭 점수 계산
  MatchScore? _calculateMatchScore({
    required WorkoutLog workout,
    required TrainingSession session,
  }) {
    // 1. 날짜 점수
    final dateScore = _calculateDateScore(
      workout.workoutDate,
      session.sessionDate,
    );
    if (dateScore == null) return null; // 날짜 차이 너무 크면 매칭 불가

    // 2. 거리 점수
    final distanceScore = _calculateDistanceScore(
      workout.distanceKm,
      session.targetDistanceKm,
    );

    // 3. 훈련 유형 점수
    final typeScore = _calculateTypeScore(
      workout: workout,
      sessionType: session.sessionType,
    );

    // 4. 시간대 점수
    final timeOfDayScore = _calculateTimeOfDayScore(
      workoutStartedAt: workout.startedAt,
    );

    return MatchScore(
      dateScore: dateScore,
      distanceScore: distanceScore,
      typeScore: typeScore,
      timeOfDayScore: timeOfDayScore,
    );
  }

  /// 날짜 매칭 점수 계산
  ///
  /// 같은 날: 1.0
  /// +/-1일: 0.5
  /// +/-2일: 0.2
  /// 3일 이상: null (매칭 불가)
  double? _calculateDateScore(DateTime workoutDate, DateTime sessionDate) {
    final dayDifference = _daysBetween(workoutDate, sessionDate).abs();

    switch (dayDifference) {
      case 0:
        return 1.0;
      case 1:
        return 0.5;
      case 2:
        return 0.2;
      default:
        return null; // 3일 이상 차이는 매칭 불가
    }
  }

  /// 거리 매칭 점수 계산
  ///
  /// 목표 거리 대비 실제 거리의 비율로 점수를 계산합니다.
  /// 비율이 1.0에 가까울수록 높은 점수를 부여합니다.
  ///
  /// 예시:
  /// - 8km 목표, 7.5km 실제 -> 비율 0.9375 -> 점수 약 0.94
  /// - 8km 목표, 10km 실제 -> 비율 1.25 -> 점수 약 0.75
  /// - 8km 목표, 4km 실제 -> 비율 0.5 -> 점수 약 0.50
  double _calculateDistanceScore(
    double actualDistanceKm,
    double? targetDistanceKm,
  ) {
    if (targetDistanceKm == null || targetDistanceKm <= 0) {
      return 0.5; // 목표 거리 없으면 중립 점수
    }

    final ratio = actualDistanceKm / targetDistanceKm;

    if (ratio < 0.2 || ratio > 3.0) {
      return 0.0; // 극단적 차이는 0점
    }

    // 비율 기반 연속 점수: 1.0에서 벗어날수록 선형 감소
    // ratio = 1.0 -> score = 1.0
    // ratio = 0.5 or 1.5 -> score = 0.5
    // ratio = 0.2 or 2.0 -> score ~= 0.2
    final deviation = (ratio - 1.0).abs();
    final score = (1.0 - deviation).clamp(0.0, 1.0);

    return score;
  }

  /// 훈련 유형 매칭 점수 계산
  ///
  /// 운동 기록의 패턴 (splits, 페이스 변화 등)을 분석하여
  /// 세션 타입과의 일치도를 평가합니다.
  double _calculateTypeScore({
    required WorkoutLog workout,
    required String sessionType,
  }) {
    // 인터벌/반복달리기 패턴 감지
    final hasIntervalPattern = _detectIntervalPattern(workout);

    switch (sessionType) {
      case 'interval':
      case 'repetition':
        // 인터벌/반복 세션: splits 패턴이 있으면 높은 점수
        return hasIntervalPattern ? 1.0 : 0.3;

      case 'easy':
      case 'recovery':
        // 이지런/회복: 균일한 페이스이고 낮은 심박수면 높은 점수
        if (hasIntervalPattern) return 0.2; // 인터벌 패턴이면 낮은 점수
        return _evaluateSteadyRunScore(workout);

      case 'long_run':
        // 장거리런: 거리가 길고 일정한 페이스
        if (hasIntervalPattern) return 0.3;
        return _evaluateLongRunScore(workout);

      case 'threshold':
        // 템포런: 중간~높은 강도, 인터벌보다는 일정한 패턴
        if (hasIntervalPattern) return 0.4;
        return _evaluateThresholdScore(workout);

      case 'marathon_pace':
        // 마라톤 페이스: 일정한 페이스
        if (hasIntervalPattern) return 0.3;
        return 0.6; // 기본 중간 점수

      case 'cross_training':
        return 0.3; // 크로스 트레이닝은 런닝 기록과 잘 안 맞음

      default:
        return 0.5; // 기본 중립 점수
    }
  }

  /// 시간대 매칭 점수 계산
  ///
  /// 운동 시작 시간을 기반으로 시간대를 평가합니다.
  /// 대부분의 러너가 아침/저녁에 달리므로 합리적인 시간대면 높은 점수를 줍니다.
  double _calculateTimeOfDayScore({
    required DateTime workoutStartedAt,
  }) {
    final hour = workoutStartedAt.hour;

    // 일반적인 훈련 시간대 (5~10시 아침, 17~21시 저녁)
    if ((hour >= 5 && hour <= 10) || (hour >= 17 && hour <= 21)) {
      return 1.0;
    }
    // 점심 시간대 (11~16시)
    if (hour >= 11 && hour <= 16) {
      return 0.7;
    }
    // 새벽/심야 (22~4시)
    return 0.4;
  }

  // -------------------------------------------------------------------------
  // 패턴 분석 헬퍼 (private)
  // -------------------------------------------------------------------------

  /// 인터벌 패턴 감지
  ///
  /// splits 데이터에서 페이스 변화가 큰 구간이 반복되면 인터벌로 판단합니다.
  /// 빠른 구간과 느린 구간의 차이가 30초/km 이상이면 인터벌 패턴으로 간주합니다.
  bool _detectIntervalPattern(WorkoutLog workout) {
    final splits = workout.splits;
    if (splits == null || splits.length < 3) return false;

    // splits에서 페이스 데이터 추출
    final paces = <int>[];
    for (final split in splits) {
      if (split is Map && split.containsKey('pace_seconds')) {
        paces.add((split['pace_seconds'] as num).toInt());
      }
    }

    if (paces.length < 3) return false;

    // 페이스 변화량 계산
    int significantChanges = 0;
    const thresholdSeconds = 30; // 30초/km 이상 변화

    for (int i = 1; i < paces.length; i++) {
      final diff = (paces[i] - paces[i - 1]).abs();
      if (diff >= thresholdSeconds) {
        significantChanges++;
      }
    }

    // 전체 구간의 30% 이상에서 큰 변화가 있으면 인터벌 패턴
    final changeRatio = significantChanges / (paces.length - 1);
    return changeRatio >= 0.3;
  }

  /// 이지런/회복 점수 평가
  ///
  /// 심박수가 낮고 페이스가 균일하면 높은 점수
  double _evaluateSteadyRunScore(WorkoutLog workout) {
    double score = 0.5; // 기본 중립

    // 심박수 기반 평가: 낮은 심박수는 이지런에 적합
    if (workout.avgHeartRate != null) {
      if (workout.avgHeartRate! < 140) {
        score += 0.2;
      } else if (workout.avgHeartRate! < 155) {
        score += 0.1;
      }
    }

    // 페이스 균일도 평가
    final paceVariation = _calculatePaceVariation(workout);
    if (paceVariation != null && paceVariation < 15) {
      score += 0.2; // 페이스 변화 15초/km 이내면 균일
    }

    return score.clamp(0.0, 1.0);
  }

  /// 장거리런 점수 평가
  double _evaluateLongRunScore(WorkoutLog workout) {
    double score = 0.5;

    // 시간이 60분 이상이면 장거리런에 적합
    if (workout.durationSeconds >= 3600) {
      score += 0.3;
    } else if (workout.durationSeconds >= 2700) {
      score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 템포런 점수 평가
  double _evaluateThresholdScore(WorkoutLog workout) {
    double score = 0.5;

    // 심박수가 중~높은 범위면 템포런에 적합
    if (workout.avgHeartRate != null) {
      if (workout.avgHeartRate! >= 155 && workout.avgHeartRate! <= 175) {
        score += 0.2;
      }
    }

    // 페이스가 비교적 균일하면 점수 추가
    final paceVariation = _calculatePaceVariation(workout);
    if (paceVariation != null && paceVariation < 20) {
      score += 0.15;
    }

    return score.clamp(0.0, 1.0);
  }

  /// 페이스 변동 계산 (표준편차와 유사한 지표)
  ///
  /// splits 데이터에서 구간 페이스의 평균 편차를 초 단위로 반환합니다.
  /// splits가 없으면 null 반환
  double? _calculatePaceVariation(WorkoutLog workout) {
    final splits = workout.splits;
    if (splits == null || splits.length < 2) return null;

    final paces = <int>[];
    for (final split in splits) {
      if (split is Map && split.containsKey('pace_seconds')) {
        paces.add((split['pace_seconds'] as num).toInt());
      }
    }

    if (paces.length < 2) return null;

    // 평균 페이스
    final avgPace = paces.reduce((a, b) => a + b) / paces.length;

    // 평균 편차
    final totalDeviation = paces.fold<double>(
      0.0,
      (sum, pace) => sum + (pace - avgPace).abs(),
    );

    return totalDeviation / paces.length;
  }

  /// 두 날짜 사이의 일수 차이 (시간 무시)
  int _daysBetween(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return aDate.difference(bDate).inDays;
  }
}

// =============================================================================
// 결과 모델
// =============================================================================

/// 단일 매칭 결과
class MatchResult {
  /// 매칭된 세션
  final TrainingSession session;

  /// 매칭 점수
  final MatchScore score;

  const MatchResult({
    required this.session,
    required this.score,
  });

  /// 완료 상태 결정
  ///
  /// 거리 달성률에 따라 completed/partial 구분:
  /// - 80% 이상 달성: completed
  /// - 50~80% 달성: partial
  /// - 50% 미만: 상태 유지 (pending)
  String determineCompletionStatus(double actualDistanceKm) {
    if (session.targetDistanceKm == null || session.targetDistanceKm == 0) {
      return 'completed';
    }

    final ratio = actualDistanceKm / session.targetDistanceKm!;
    if (ratio >= 0.8) return 'completed';
    if (ratio >= 0.5) return 'partial';
    return 'pending'; // 50% 미만은 상태 유지
  }
}

/// 매칭 점수
class MatchScore {
  /// 날짜 매칭 점수 (0.0~1.0)
  final double dateScore;

  /// 거리 매칭 점수 (0.0~1.0)
  final double distanceScore;

  /// 훈련 유형 매칭 점수 (0.0~1.0)
  final double typeScore;

  /// 시간대 매칭 점수 (0.0~1.0)
  final double timeOfDayScore;

  const MatchScore({
    required this.dateScore,
    required this.distanceScore,
    required this.typeScore,
    required this.timeOfDayScore,
  });

  /// 종합 매칭 점수
  /// 날짜 50% + 거리 30% + 훈련유형 15% + 시간대 5%
  double get totalScore =>
      dateScore * MatchWorkoutToSession._dateWeight +
      distanceScore * MatchWorkoutToSession._distanceWeight +
      typeScore * MatchWorkoutToSession._typeWeight +
      timeOfDayScore * MatchWorkoutToSession._timeOfDayWeight;

  /// 매칭 신뢰도 레벨
  MatchConfidence get confidence {
    if (totalScore >= 0.8) return MatchConfidence.high;
    if (totalScore >= 0.5) return MatchConfidence.medium;
    return MatchConfidence.low;
  }

  /// 디버그용 상세 점수 맵
  Map<String, double> toDetailMap() => {
        'date': dateScore,
        'distance': distanceScore,
        'type': typeScore,
        'timeOfDay': timeOfDayScore,
        'total': totalScore,
      };

  @override
  String toString() =>
      'MatchScore(date: ${dateScore.toStringAsFixed(2)}, '
      'distance: ${distanceScore.toStringAsFixed(2)}, '
      'type: ${typeScore.toStringAsFixed(2)}, '
      'timeOfDay: ${timeOfDayScore.toStringAsFixed(2)}, '
      'total: ${totalScore.toStringAsFixed(2)})';
}

/// 매칭 신뢰도
enum MatchConfidence {
  /// 높음 (같은 날, 거리/유형 모두 유사)
  high,

  /// 중간 (날짜 근접 또는 일부 기준 불일치)
  medium,

  /// 낮음 (날짜/거리/유형 모두 차이 있음)
  low,
}

/// 일괄 매칭 결과
class BatchMatchResult {
  /// 매칭된 (운동, 세션) 쌍 목록
  final List<MatchedPair> matchedPairs;

  /// 매칭되지 않은 운동 목록 (자유 운동)
  final List<WorkoutLog> unmatchedWorkouts;

  const BatchMatchResult({
    required this.matchedPairs,
    required this.unmatchedWorkouts,
  });

  /// 매칭된 운동 수
  int get matchedCount => matchedPairs.length;

  /// 매칭되지 않은 운동 수
  int get unmatchedCount => unmatchedWorkouts.length;

  /// 총 운동 수
  int get totalCount => matchedCount + unmatchedCount;

  /// 매칭 성공률 (%)
  double get matchRate =>
      totalCount > 0 ? (matchedCount / totalCount * 100) : 0.0;

  @override
  String toString() =>
      'BatchMatchResult(matched: $matchedCount, unmatched: $unmatchedCount, '
      'rate: ${matchRate.toStringAsFixed(1)}%)';
}

/// 매칭된 운동-세션 쌍
class MatchedPair {
  /// 운동 기록
  final WorkoutLog workout;

  /// 매칭된 훈련 세션
  final TrainingSession session;

  /// 매칭 점수
  final MatchScore score;

  const MatchedPair({
    required this.workout,
    required this.session,
    required this.score,
  });

  /// 완료 상태 결정
  String get completionStatus {
    if (session.targetDistanceKm == null || session.targetDistanceKm == 0) {
      return 'completed';
    }
    final ratio = workout.distanceKm / session.targetDistanceKm!;
    if (ratio >= 0.8) return 'completed';
    if (ratio >= 0.5) return 'partial';
    return 'pending';
  }
}

// =============================================================================
// 내부 모델
// =============================================================================

/// 매칭 후보 (내부 정렬용)
class _MatchCandidate {
  final WorkoutLog workout;
  final TrainingSession session;
  final MatchScore score;

  const _MatchCandidate({
    required this.workout,
    required this.session,
    required this.score,
  });
}
