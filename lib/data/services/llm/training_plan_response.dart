/// LLM이 반환하는 훈련표 JSON 응답의 파싱 모델
///
/// LLM 응답 JSON을 파싱하여 구조화된 객체로 변환합니다.
/// 파싱 실패 시 적절한 에러를 제공합니다.
class TrainingPlanResponse {
  final String planName;
  final String planOverview;
  final List<WeekResponse> weeks;

  const TrainingPlanResponse({
    required this.planName,
    required this.planOverview,
    required this.weeks,
  });

  /// JSON 파싱
  ///
  /// 파싱 실패 시 [FormatException]을 throw합니다.
  factory TrainingPlanResponse.fromJson(Map<String, dynamic> json) {
    try {
      final planName = json['plan_name'] as String? ?? '';
      final planOverview = json['plan_overview'] as String? ?? '';
      final weeksJson = json['weeks'] as List<dynamic>? ?? [];

      final weeks = weeksJson
          .map((w) => WeekResponse.fromJson(w as Map<String, dynamic>))
          .toList();

      if (weeks.isEmpty) {
        throw const FormatException('훈련표에 주차 데이터가 없습니다.');
      }

      return TrainingPlanResponse(
        planName: planName,
        planOverview: planOverview,
        weeks: weeks,
      );
    } catch (e) {
      if (e is FormatException) rethrow;
      throw FormatException('훈련표 JSON 파싱 실패: $e');
    }
  }

  /// 전체 세션 수
  int get totalSessions =>
      weeks.fold(0, (sum, w) => sum + w.sessions.length);

  /// 전체 훈련 세션 수 (rest 제외)
  int get totalTrainingSessions => weeks.fold(
      0,
      (sum, w) =>
          sum +
          w.sessions.where((s) => s.sessionType != 'rest').length);
}

/// 주차 응답 모델
class WeekResponse {
  final int weekNumber;
  final String phase;
  final String? weeklySummary;
  final double? targetDistanceKm;
  final List<SessionResponse> sessions;

  const WeekResponse({
    required this.weekNumber,
    required this.phase,
    this.weeklySummary,
    this.targetDistanceKm,
    required this.sessions,
  });

  factory WeekResponse.fromJson(Map<String, dynamic> json) {
    final sessionsJson = json['sessions'] as List<dynamic>? ?? [];

    return WeekResponse(
      weekNumber: json['week_number'] as int? ?? 1,
      phase: _validatePhase(json['phase'] as String? ?? 'base'),
      weeklySummary: json['weekly_summary'] as String?,
      targetDistanceKm: (json['target_distance_km'] as num?)?.toDouble(),
      sessions: sessionsJson
          .map((s) => SessionResponse.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  /// phase 값 검증
  static String _validatePhase(String phase) {
    const validPhases = ['base', 'build', 'peak', 'taper'];
    if (validPhases.contains(phase)) return phase;
    // 유사한 값 매핑
    switch (phase.toLowerCase()) {
      case 'foundation':
      case 'basic':
        return 'base';
      case 'development':
      case 'building':
        return 'build';
      case 'peaking':
      case 'sharpening':
        return 'peak';
      case 'tapering':
      case 'recovery':
        return 'taper';
      default:
        return 'base';
    }
  }
}

/// 세션 응답 모델
class SessionResponse {
  final int dayOfWeek;
  final String sessionType;
  final String title;
  final String? description;
  final double? targetDistanceKm;
  final int? targetDurationMinutes;
  final String? targetPace;
  final Map<String, dynamic>? workoutDetail;

  const SessionResponse({
    required this.dayOfWeek,
    required this.sessionType,
    required this.title,
    this.description,
    this.targetDistanceKm,
    this.targetDurationMinutes,
    this.targetPace,
    this.workoutDetail,
  });

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      dayOfWeek: _clampDayOfWeek(json['day_of_week'] as int? ?? 1),
      sessionType:
          _validateSessionType(json['session_type'] as String? ?? 'easy'),
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      targetDistanceKm:
          (json['target_distance_km'] as num?)?.toDouble(),
      targetDurationMinutes:
          json['target_duration_minutes'] as int?,
      targetPace: json['target_pace'] as String?,
      workoutDetail:
          json['workout_detail'] as Map<String, dynamic>?,
    );
  }

  /// day_of_week를 1~7 범위로 클램프
  static int _clampDayOfWeek(int day) {
    if (day < 1) return 1;
    if (day > 7) return 7;
    return day;
  }

  /// session_type 값 검증
  static String _validateSessionType(String type) {
    const validTypes = [
      'easy',
      'marathon_pace',
      'threshold',
      'interval',
      'repetition',
      'long_run',
      'recovery',
      'cross_training',
      'rest',
    ];
    if (validTypes.contains(type)) return type;

    // 유사한 값 매핑
    switch (type.toLowerCase()) {
      case 'e':
      case 'easy_run':
      case 'e_run':
      case 'jog':
        return 'easy';
      case 'm':
      case 'marathon':
      case 'm_pace':
        return 'marathon_pace';
      case 't':
      case 'tempo':
      case 'tempo_run':
      case 't_run':
        return 'threshold';
      case 'i':
      case 'intervals':
      case 'i_run':
        return 'interval';
      case 'r':
      case 'rep':
      case 'reps':
      case 'r_run':
        return 'repetition';
      case 'long':
      case 'lr':
        return 'long_run';
      case 'rec':
      case 'recovery_run':
        return 'recovery';
      case 'cross':
      case 'xt':
      case 'cross-training':
        return 'cross_training';
      case 'off':
      case 'day_off':
        return 'rest';
      default:
        return 'easy';
    }
  }
}
