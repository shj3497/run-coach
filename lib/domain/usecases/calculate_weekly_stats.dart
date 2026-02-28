import '../../data/models/training_session.dart';

/// 주간 통계 계산 유스케이스
///
/// 특정 주차의 훈련 세션들을 분석하여 달성도 통계를 생성합니다.
/// Repository를 직접 의존하지 않고, 세션 데이터를 입력으로 받아 순수 계산만 수행합니다.
class CalculateWeeklyStats {
  const CalculateWeeklyStats();

  /// 주간 통계 계산 실행
  ///
  /// [sessions] 해당 주차의 모든 훈련 세션 목록
  /// [targetDistanceKm] 주간 목표 거리 (km). null이면 세션 목표의 합으로 대체
  ///
  /// 반환: [WeeklyStats] 주간 통계
  WeeklyStats execute({
    required List<TrainingSession> sessions,
    double? targetDistanceKm,
  }) {
    // 훈련 세션만 (rest 제외)
    final trainingSessions =
        sessions.where((s) => s.sessionType != 'rest').toList();

    // 완료된 세션
    final completedSessions =
        trainingSessions.where((s) => s.status == 'completed').toList();

    // 건너뛴 세션
    final skippedSessions =
        trainingSessions.where((s) => s.status == 'skipped').toList();

    // 부분 완료 세션
    final partialSessions =
        trainingSessions.where((s) => s.status == 'partial').toList();

    // 대기 중 세션
    final pendingSessions =
        trainingSessions.where((s) => s.status == 'pending').toList();

    // 목표 거리 계산
    final calculatedTargetDistanceKm = targetDistanceKm ??
        trainingSessions.fold<double>(
          0.0,
          (sum, s) => sum + (s.targetDistanceKm ?? 0.0),
        );

    // 완료된 세션의 목표 거리 합
    final completedDistanceKm = completedSessions.fold<double>(
      0.0,
      (sum, s) => sum + (s.targetDistanceKm ?? 0.0),
    );

    // 부분 완료 포함 거리 (50% 가중치)
    final partialDistanceKm = partialSessions.fold<double>(
      0.0,
      (sum, s) => sum + (s.targetDistanceKm ?? 0.0) * 0.5,
    );

    final totalCompletedDistanceKm = completedDistanceKm + partialDistanceKm;

    // 세션 완료율
    final sessionCompletionRate = trainingSessions.isEmpty
        ? 0.0
        : (completedSessions.length + partialSessions.length * 0.5) /
            trainingSessions.length *
            100;

    // 거리 완료율
    final distanceCompletionRate = calculatedTargetDistanceKm <= 0
        ? 0.0
        : (totalCompletedDistanceKm / calculatedTargetDistanceKm * 100)
            .clamp(0.0, 100.0);

    // 세션 유형별 통계
    final sessionTypeBreakdown = <String, int>{};
    for (final session in trainingSessions) {
      sessionTypeBreakdown[session.sessionType] =
          (sessionTypeBreakdown[session.sessionType] ?? 0) + 1;
    }

    final completedSessionTypeBreakdown = <String, int>{};
    for (final session in completedSessions) {
      completedSessionTypeBreakdown[session.sessionType] =
          (completedSessionTypeBreakdown[session.sessionType] ?? 0) + 1;
    }

    return WeeklyStats(
      totalSessions: trainingSessions.length,
      completedSessions: completedSessions.length,
      skippedSessions: skippedSessions.length,
      partialSessions: partialSessions.length,
      pendingSessions: pendingSessions.length,
      targetDistanceKm: calculatedTargetDistanceKm,
      completedDistanceKm: totalCompletedDistanceKm,
      sessionCompletionRate: _roundToOneDecimal(sessionCompletionRate),
      distanceCompletionRate: _roundToOneDecimal(distanceCompletionRate),
      sessionTypeBreakdown: sessionTypeBreakdown,
      completedSessionTypeBreakdown: completedSessionTypeBreakdown,
    );
  }

  /// 소수점 1자리로 반올림
  double _roundToOneDecimal(double value) {
    return (value * 10).round() / 10.0;
  }
}

/// 주간 통계 결과
class WeeklyStats {
  /// 총 훈련 세션 수 (rest 제외)
  final int totalSessions;

  /// 완료된 세션 수
  final int completedSessions;

  /// 건너뛴 세션 수
  final int skippedSessions;

  /// 부분 완료된 세션 수
  final int partialSessions;

  /// 대기 중 세션 수
  final int pendingSessions;

  /// 주간 목표 거리 (km)
  final double targetDistanceKm;

  /// 완료된 거리 (km) - 부분 완료 포함
  final double completedDistanceKm;

  /// 세션 완료율 (%) - 0.0~100.0
  final double sessionCompletionRate;

  /// 거리 완료율 (%) - 0.0~100.0
  final double distanceCompletionRate;

  /// 세션 유형별 총 수
  final Map<String, int> sessionTypeBreakdown;

  /// 세션 유형별 완료 수
  final Map<String, int> completedSessionTypeBreakdown;

  const WeeklyStats({
    required this.totalSessions,
    required this.completedSessions,
    required this.skippedSessions,
    required this.partialSessions,
    required this.pendingSessions,
    required this.targetDistanceKm,
    required this.completedDistanceKm,
    required this.sessionCompletionRate,
    required this.distanceCompletionRate,
    required this.sessionTypeBreakdown,
    required this.completedSessionTypeBreakdown,
  });

  /// 전체 완료 여부
  bool get isFullyCompleted =>
      completedSessions == totalSessions && totalSessions > 0;

  /// 남은 세션 수
  int get remainingSessions => pendingSessions;

  /// 남은 거리 (km)
  double get remainingDistanceKm =>
      (targetDistanceKm - completedDistanceKm).clamp(0.0, double.infinity);

  /// 종합 달성률 (세션 + 거리의 가중 평균)
  ///
  /// 세션 완료율 60% + 거리 완료율 40% 가중치
  double get overallCompletionRate {
    return (sessionCompletionRate * 0.6 + distanceCompletionRate * 0.4);
  }

  /// LLM 주간 리뷰 context용 JSON 변환
  Map<String, dynamic> toContextJson() {
    return {
      'total_sessions': totalSessions,
      'completed_sessions': completedSessions,
      'skipped_sessions': skippedSessions,
      'partial_sessions': partialSessions,
      'pending_sessions': pendingSessions,
      'target_distance_km': targetDistanceKm,
      'completed_distance_km': completedDistanceKm,
      'session_completion_rate': sessionCompletionRate,
      'distance_completion_rate': distanceCompletionRate,
      'overall_completion_rate':
          (overallCompletionRate * 10).round() / 10.0,
      'session_type_breakdown': sessionTypeBreakdown,
      'completed_session_type_breakdown': completedSessionTypeBreakdown,
    };
  }

  @override
  String toString() {
    return 'WeeklyStats('
        'sessions: $completedSessions/$totalSessions ($sessionCompletionRate%), '
        'distance: ${completedDistanceKm.toStringAsFixed(1)}/${targetDistanceKm.toStringAsFixed(1)}km ($distanceCompletionRate%)'
        ')';
  }
}
