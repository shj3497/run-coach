import '../../data/models/training_session.dart';

/// 운동 기록을 훈련 세션에 매칭하는 유스케이스
///
/// HealthKit/Strava에서 가져온 실제 운동 기록을
/// 활성 훈련 플랜의 세션에 자동 매칭합니다.
///
/// 매칭 기준:
/// 1. 날짜 일치 (1순위)
/// 2. 날짜 근접 (전후 1일, 2순위)
/// 3. 거리 유사도 (보조 기준)
class MatchWorkoutToSession {
  const MatchWorkoutToSession();

  /// 운동 기록에 가장 적합한 훈련 세션을 매칭
  ///
  /// [workoutDate] 운동 날짜
  /// [workoutDistanceKm] 운동 거리 (km)
  /// [pendingSessions] 매칭 후보 세션 목록 (status: pending인 세션들)
  ///
  /// 반환: 매칭된 세션과 매칭 점수. 적합한 세션이 없으면 null
  MatchResult? execute({
    required DateTime workoutDate,
    required double workoutDistanceKm,
    required List<TrainingSession> pendingSessions,
  }) {
    if (pendingSessions.isEmpty) return null;

    // rest 세션 제외
    final candidates =
        pendingSessions.where((s) => s.sessionType != 'rest').toList();

    if (candidates.isEmpty) return null;

    MatchResult? bestMatch;

    for (final session in candidates) {
      final score = _calculateMatchScore(
        workoutDate: workoutDate,
        workoutDistanceKm: workoutDistanceKm,
        session: session,
      );

      if (score == null) continue;

      if (bestMatch == null || score.totalScore > bestMatch.score.totalScore) {
        bestMatch = MatchResult(session: session, score: score);
      }
    }

    // 최소 매칭 점수 기준 (0.3 이상이어야 매칭)
    if (bestMatch != null && bestMatch.score.totalScore < 0.3) {
      return null;
    }

    return bestMatch;
  }

  /// 매칭 점수 계산
  ///
  /// 점수 구성:
  /// - 날짜 점수 (0.0~1.0, 가중치 60%)
  /// - 거리 점수 (0.0~1.0, 가중치 40%)
  MatchScore? _calculateMatchScore({
    required DateTime workoutDate,
    required double workoutDistanceKm,
    required TrainingSession session,
  }) {
    // 날짜 점수
    final dayDifference =
        _daysBetween(workoutDate, session.sessionDate).abs();

    double dateScore;
    if (dayDifference == 0) {
      dateScore = 1.0; // 같은 날
    } else if (dayDifference == 1) {
      dateScore = 0.5; // 하루 차이
    } else if (dayDifference == 2) {
      dateScore = 0.2; // 이틀 차이
    } else {
      return null; // 3일 이상 차이는 매칭 불가
    }

    // 거리 점수
    double distanceScore;
    if (session.targetDistanceKm == null || session.targetDistanceKm == 0) {
      // 목표 거리가 없으면 거리 점수 0.5 (중립)
      distanceScore = 0.5;
    } else {
      final distanceRatio =
          workoutDistanceKm / session.targetDistanceKm!;
      // 비율이 0.5~1.5 범위면 매칭 가능
      if (distanceRatio < 0.3 || distanceRatio > 2.0) {
        distanceScore = 0.0;
      } else if (distanceRatio >= 0.8 && distanceRatio <= 1.2) {
        // 80~120% 범위: 높은 점수
        distanceScore = 1.0 - (distanceRatio - 1.0).abs() * 2;
      } else {
        // 그 외: 중간 점수
        distanceScore = 0.3;
      }
    }

    return MatchScore(
      dateScore: dateScore,
      distanceScore: distanceScore,
    );
  }

  /// 두 날짜 사이의 일수 차이 (시간 무시)
  int _daysBetween(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return aDate.difference(bDate).inDays;
  }
}

/// 매칭 결과
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
  /// - 50% 미만: partial (미달성이지만 기록은 유지)
  String determineCompletionStatus(double actualDistanceKm) {
    if (session.targetDistanceKm == null || session.targetDistanceKm == 0) {
      return 'completed';
    }

    final ratio = actualDistanceKm / session.targetDistanceKm!;
    if (ratio >= 0.8) return 'completed';
    return 'partial';
  }
}

/// 매칭 점수
class MatchScore {
  /// 날짜 매칭 점수 (0.0~1.0)
  final double dateScore;

  /// 거리 매칭 점수 (0.0~1.0)
  final double distanceScore;

  const MatchScore({
    required this.dateScore,
    required this.distanceScore,
  });

  /// 종합 매칭 점수 (날짜 60%, 거리 40%)
  double get totalScore => dateScore * 0.6 + distanceScore * 0.4;

  /// 매칭 신뢰도 레벨
  MatchConfidence get confidence {
    if (totalScore >= 0.8) return MatchConfidence.high;
    if (totalScore >= 0.5) return MatchConfidence.medium;
    return MatchConfidence.low;
  }

  @override
  String toString() =>
      'MatchScore(date: $dateScore, distance: $distanceScore, total: $totalScore)';
}

/// 매칭 신뢰도
enum MatchConfidence {
  /// 높음 (같은 날, 거리도 유사)
  high,

  /// 중간 (날짜 근접 또는 거리 약간 차이)
  medium,

  /// 낮음 (날짜/거리 모두 차이 있음)
  low,
}
