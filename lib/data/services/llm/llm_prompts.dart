/// LLM 프롬프트 템플릿
///
/// 모든 LLM 프롬프트를 이 파일에서 관리합니다.
/// 프롬프트 수정 시 이 파일만 변경하면 됩니다.
class LLMPrompts {
  LLMPrompts._();

  // ---------------------------------------------------------------------------
  // 훈련표 생성
  // ---------------------------------------------------------------------------

  /// 훈련표 생성 시스템 프롬프트
  static const String trainingPlanSystemPrompt = '''
당신은 전문 런닝 코치입니다. Jack Daniels의 VDOT 시스템에 기반하여 개인화된 훈련표를 작성합니다.

핵심 원칙:
1. 각 세션의 target_pace와 workout_detail.pace_range는 반드시 제공된 pace_zones 데이터에서 해당 session_type에 맞는 페이스를 그대로 사용해야 합니다.
   - easy, recovery, long_run → pace_zones.E의 min_pace~max_pace 범위
   - marathon_pace → pace_zones.M의 pace
   - threshold → pace_zones.T의 pace
   - interval → pace_zones.I의 pace (E 페이스보다 반드시 빨라야 합니다)
   - repetition → pace_zones.R의 pace (I 페이스보다 반드시 빨라야 합니다)
   절대로 임의의 페이스를 생성하지 마세요. pace_zones에 제공된 값을 그대로 사용하세요.
2. 주기화(Periodization) 원칙을 따릅니다: base -> build -> peak -> taper
3. 주간 훈련량(거리)은 점진적으로 증가하되, 3주 증가 후 1주 회복(10~15% 감소)을 반복합니다.
4. 훈련 강도 배분: 이지런이 전체의 70~80%, 나머지 20~30%가 M/T/I/R
5. 장거리런(Long Run)은 주 1회, 주간 총 거리의 25~30% 이내
6. 사용자의 경험 수준과 훈련 가용일수를 반드시 고려합니다.

응답은 반드시 지정된 JSON 형식으로 작성하세요.
''';

  /// 훈련표 청크 단위 생성 프롬프트
  ///
  /// 전체 훈련표를 한 번에 생성하면 LLM이 일부 주차만 생성하는 문제가 있어
  /// 8주 단위로 나누어 생성합니다.
  ///
  /// [contextJson] 구조화된 훈련 context JSON 문자열
  /// [startWeek] 이번 청크의 시작 주차 (1부터)
  /// [endWeek] 이번 청크의 끝 주차
  /// [totalWeeks] 전체 훈련 주수
  /// [includeOverview] true면 plan_name, plan_overview도 포함 (첫 번째 청크)
  static String trainingPlanChunkPrompt({
    required String contextJson,
    required int startWeek,
    required int endWeek,
    required int totalWeeks,
    required bool includeOverview,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(
        '아래 데이터를 기반으로 훈련표의 $startWeek~$endWeek주차를 생성해주세요.');
    buffer.writeln('(전체 $totalWeeks주 중 $startWeek-$endWeek주차)');
    buffer.writeln('');
    buffer.writeln(contextJson);
    buffer.writeln('');
    buffer.writeln('다음 JSON 형식으로 응답해주세요:');
    buffer.writeln('{');

    if (includeOverview) {
      buffer.writeln(
          '  "plan_name": "플랜 이름 (한국어, 예: \'2025 JTBC 하프 1:55 도전\')",');
      buffer.writeln(
          '  "plan_overview": "전체 훈련 계획에 대한 코칭 설명 (한국어, 2~3문단)",');
    }

    buffer.writeln('  "weeks": [');
    buffer.writeln('    {');
    buffer.writeln('      "week_number": $startWeek,');
    buffer.writeln('      "phase": "base | build | peak | taper",');
    buffer.writeln('      "weekly_summary": "이번 주 목표 (한국어, 1문장)",');
    buffer.writeln('      "target_distance_km": 30,');
    buffer.writeln('      "sessions": [');
    buffer.writeln('        {');
    buffer.writeln('          "day_of_week": 1,');
    buffer.writeln(
        '          "session_type": "easy | marathon_pace | threshold | interval | repetition | long_run | recovery | cross_training",');
    buffer.writeln('          "title": "훈련 제목 (한국어)",');
    buffer.writeln('          "description": "1문장 설명",');
    buffer.writeln('          "target_distance_km": 8.0,');
    buffer.writeln('          "target_duration_minutes": 50,');
    buffer.writeln(
        '          "target_pace": "pace_zones에서 해당 존 페이스 사용 (예: easy→E존, interval→I존)",');
    buffer.writeln('          "workout_detail": {');
    buffer.writeln(
        '            "type": "steady | intervals | tempo | progression",');
    buffer.writeln(
        '            "pace_range": {"min": "해당 존 페이스", "max": "해당 존 페이스"}');
    buffer.writeln('          }');
    buffer.writeln('        }');
    buffer.writeln('      ]');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('주의사항:');
    buffer.writeln(
        '- $startWeek주차부터 $endWeek주차까지 빠짐없이 모두 생성하세요');
    buffer.writeln('- day_of_week: 1=월요일 ~ 7=일요일');
    buffer.writeln('- 훈련 세션만 포함 (휴식일 제외)');
    buffer.writeln('- 각 주에는 정확히 주당 훈련일수만큼의 세션만 포함');
    buffer.writeln(
        '- workout_detail.type: easy/recovery→"steady", marathon_pace/threshold→"tempo", interval/repetition→"intervals", long_run→"steady" 또는 "progression"');
    buffer.writeln('- description은 1문장으로 간결하게');
    buffer.writeln('- 모든 설명은 한국어로');
    buffer.writeln(
        '- [필수] target_pace는 반드시 위 pace_zones 데이터에서 가져오세요:');
    buffer.writeln('  · easy/recovery/long_run → E존 min_pace~max_pace');
    buffer.writeln('  · marathon_pace → M존 pace');
    buffer.writeln('  · threshold → T존 pace');
    buffer.writeln('  · interval → I존 pace (E존보다 빠름)');
    buffer.writeln('  · repetition → R존 pace (I존보다 빠름)');
    buffer.writeln(
        '- 페이스 순서: R < I < T < M < E (숫자가 작을수록 빠름). 임의로 페이스를 생성하지 마세요');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 주간 리뷰
  // ---------------------------------------------------------------------------

  /// 주간 리뷰 시스템 프롬프트
  static const String weeklyReviewSystemPrompt = '''
당신은 전문 런닝 코치입니다. 이번 주 훈련 달성도를 분석하고, 격려와 함께 다음 주 조언을 제공합니다.

원칙:
1. 긍정적이고 격려하는 톤을 유지합니다.
2. 데이터 기반으로 구체적인 피드백을 제공합니다.
3. 달성하지 못한 부분은 비난하지 않고 개선 방안을 제시합니다.
4. 다음 주 훈련의 핵심 포인트를 명확히 전달합니다.
5. 훈련 존 용어는 반드시 한글 풀네임을 사용합니다:
   - 이지런 (Easy Run), 마라톤페이스 (Marathon Pace), 템포런 (Threshold Run)
   - 인터벌 (Interval), 반복달리기 (Repetition), 장거리런 (Long Run)
   - E런, T런, M페이스 등 약어는 절대 사용하지 마세요.

응답은 반드시 아래 JSON 형식으로 작성하세요:
{
  "summary": "이번 주 전체 요약 (1~2문장)",
  "highlights": ["잘한 점 1", "잘한 점 2"],
  "improvements": ["개선점 1"],
  "next_week_advice": "다음 주 핵심 조언 (1~2문장)"
}

한국어로 작성하세요.
''';

  /// 주간 리뷰 사용자 프롬프트 템플릿
  static String weeklyReviewUserPrompt(String contextJson) {
    return '''
이번 주 훈련 결과를 분석하고 코칭 메시지를 작성해주세요.

$contextJson
''';
  }

  // ---------------------------------------------------------------------------
  // 세션 피드백
  // ---------------------------------------------------------------------------

  /// 세션 피드백 시스템 프롬프트
  static const String sessionFeedbackSystemPrompt = '''
당신은 전문 런닝 코치입니다. 개별 훈련 세션의 결과를 간단히 피드백합니다.

원칙:
1. 간결하게 1~2문장으로 피드백합니다.
2. 목표 대비 실제 성과를 비교합니다.
3. 격려하는 톤을 유지합니다.
4. 날씨 정보가 제공된 경우, 날씨를 고려한 피드백을 제공합니다.
5. 훈련 존 용어는 한글 풀네임을 사용합니다 (이지런, 템포런, 마라톤페이스 등).

응답은 한국어로 작성하세요. 100자 이내로 작성하세요.
''';

  // ---------------------------------------------------------------------------
  // 날씨 기반 페이스 보정
  // ---------------------------------------------------------------------------

  /// 날씨 페이스 보정 시스템 프롬프트
  static const String weatherAdjustmentSystemPrompt = '''
당신은 전문 런닝 코치입니다. 현재 날씨를 고려하여 오늘 훈련의 페이스 보정을 제안합니다.

페이스 보정은 이미 계산되어 있습니다. 계산된 보정 비율과 보정된 페이스를 참고하여
러너에게 따뜻하고 격려하는 톤으로 안내 메시지를 작성하세요.

추가 고려사항:
- 비/눈이 올 경우 미끄럼 주의
- 강풍(8m/s 이상)일 경우 바람 방향 고려
- 30도C 이상이면 실내 러닝 권장 가능
- 0도C 이하이면 보온 주의

훈련 존 용어는 한글 풀네임을 사용합니다 (이지런, 템포런, 마라톤페이스 등).
응답은 한국어로 작성하세요. 150자 이내로 간결하게 작성하세요.
''';

  /// 동기부여 시스템 프롬프트
  static const String encouragementSystemPrompt = '''
당신은 따뜻하고 전문적인 런닝 코치입니다.
사용자에게 동기부여 메시지를 전달합니다.
훈련 데이터와 목표를 참고하여 개인화된 응원 메시지를 작성합니다.
한국어로 응답하고, 진심이 담긴 톤으로 작성하세요.
100자 이내로 간결하게 작성하세요.
''';

  // ---------------------------------------------------------------------------
  // 프롬프트 빌더 메서드
  // ---------------------------------------------------------------------------

  /// 훈련표 생성 사용자 프롬프트 빌더 (구조화된 데이터 기반)
  static String buildTrainingPlanUserPrompt({
    double? vdotScore,
    Map<String, String>? paceZones,
    required double goalDistanceKm,
    int? goalTimeSeconds,
    required int trainingDaysPerWeek,
    required int totalWeeks,
    String? runningExperience,
    double? recentWeeklyDistanceKm,
    String? goalRaceName,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('=== 사용자 정보 ===');

    if (vdotScore != null) {
      buffer.writeln('VDOT 점수: $vdotScore');
    } else {
      buffer.writeln('VDOT 점수: 미산출 (대회 기록 없음)');
    }

    if (paceZones != null && paceZones.isNotEmpty) {
      buffer.writeln('페이스 존:');
      paceZones.forEach((zone, pace) {
        buffer.writeln('  $zone: $pace');
      });
    }

    buffer.writeln('러닝 경험: ${runningExperience ?? "미입력"}');

    if (recentWeeklyDistanceKm != null) {
      buffer.writeln(
          '최근 주간 평균 러닝 거리: ${recentWeeklyDistanceKm.toStringAsFixed(1)}km');
    }

    buffer.writeln('');
    buffer.writeln('=== 훈련 목표 ===');

    if (goalRaceName != null) {
      buffer.writeln('목표 대회: $goalRaceName');
    }

    buffer.writeln('목표 거리: ${goalDistanceKm}km');

    if (goalTimeSeconds != null) {
      final hours = goalTimeSeconds ~/ 3600;
      final minutes = (goalTimeSeconds % 3600) ~/ 60;
      final seconds = goalTimeSeconds % 60;
      if (hours > 0) {
        buffer.writeln(
            '목표 시간: $hours시간 $minutes분${seconds > 0 ? " $seconds초" : ""}');
      } else {
        buffer.writeln(
            '목표 시간: $minutes분${seconds > 0 ? " $seconds초" : ""}');
      }
    } else {
      buffer.writeln('목표: 완주');
    }

    buffer.writeln('');
    buffer.writeln('=== 훈련 조건 ===');
    buffer.writeln('주간 훈련 가능 일수: $trainingDaysPerWeek일');
    buffer.writeln('총 훈련 기간: $totalWeeks주');

    buffer.writeln('');
    buffer.writeln('=== 요청 ===');
    buffer.writeln(
        '위 정보를 기반으로 $totalWeeks주간의 개인화 훈련표를 JSON 형식으로 생성해주세요.');
    buffer.writeln('각 주에는 정확히 $trainingDaysPerWeek개의 훈련 세션을 배치하세요.');
    buffer.writeln('훈련이 없는 요일은 rest 세션으로 채워서 총 7일을 채워주세요.');

    return buffer.toString();
  }

  /// 주간 리뷰 사용자 프롬프트 빌더
  static String buildWeeklyReviewPrompt({
    required int weekNumber,
    required String phase,
    required int totalSessions,
    required int completedSessions,
    required int skippedSessions,
    double? targetDistanceKm,
    double? actualDistanceKm,
    String? weeklySummary,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('=== $weekNumber주차 훈련 결과 ===');
    buffer.writeln('훈련 단계: $phase');
    buffer.writeln('계획 세션: $totalSessions개');
    buffer.writeln('완료: $completedSessions개');
    buffer.writeln('스킵: $skippedSessions개');

    final rate = totalSessions > 0
        ? (completedSessions / totalSessions * 100).toStringAsFixed(0)
        : '0';
    buffer.writeln('달성률: $rate%');

    if (targetDistanceKm != null) {
      buffer.writeln('목표 거리: ${targetDistanceKm.toStringAsFixed(1)}km');
    }
    if (actualDistanceKm != null) {
      buffer.writeln('실제 거리: ${actualDistanceKm.toStringAsFixed(1)}km');
    }

    if (weeklySummary != null) {
      buffer.writeln('주간 훈련 목표: $weeklySummary');
    }

    buffer.writeln('');
    buffer.writeln('위 결과를 바탕으로 주간 리뷰 코칭 메시지를 작성해주세요.');

    return buffer.toString();
  }

  /// 세션 피드백 사용자 프롬프트 빌더
  static String buildSessionFeedbackPrompt({
    required String sessionTitle,
    required String sessionType,
    double? targetDistanceKm,
    double? actualDistanceKm,
    String? targetPace,
    int? actualPaceSecondsPerKm,
    int? avgHeartRate,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('=== 훈련 결과 ===');
    buffer.writeln('훈련: $sessionTitle ($sessionType)');

    if (targetDistanceKm != null) {
      buffer.writeln('목표 거리: ${targetDistanceKm.toStringAsFixed(1)}km');
    }
    if (actualDistanceKm != null) {
      buffer.writeln('실제 거리: ${actualDistanceKm.toStringAsFixed(1)}km');
    }
    if (targetPace != null) {
      buffer.writeln('목표 페이스: $targetPace');
    }
    if (actualPaceSecondsPerKm != null) {
      final min = actualPaceSecondsPerKm ~/ 60;
      final sec = actualPaceSecondsPerKm % 60;
      buffer.writeln(
          '실제 페이스: $min:${sec.toString().padLeft(2, '0')}/km');
    }
    if (avgHeartRate != null) {
      buffer.writeln('평균 심박수: ${avgHeartRate}bpm');
    }

    buffer.writeln('');
    buffer.writeln('위 결과에 대해 짧은 피드백을 해주세요.');

    return buffer.toString();
  }

  /// 페이스 보정 사용자 프롬프트 빌더
  static String buildPaceAdjustmentPrompt({
    required String sessionTitle,
    required String sessionType,
    String? targetPace,
    required double temperatureC,
    required int humidity,
    String? weatherCondition,
    double? windSpeedMs,
    double? adjustmentPercent,
    String? adjustedPaceRange,
  }) {
    final buffer = StringBuffer();

    buffer.writeln('=== 오늘의 훈련 ===');
    buffer.writeln('훈련: $sessionTitle ($sessionType)');
    if (targetPace != null) {
      buffer.writeln('원래 목표 페이스: $targetPace');
    }

    buffer.writeln('');
    buffer.writeln('=== 현재 날씨 ===');
    buffer.writeln('기온: ${temperatureC.toStringAsFixed(1)}°C');
    buffer.writeln('습도: $humidity%');
    if (windSpeedMs != null) {
      buffer.writeln('풍속: ${windSpeedMs.toStringAsFixed(1)}m/s');
    }
    if (weatherCondition != null) {
      buffer.writeln('날씨 상태: $weatherCondition');
    }

    if (adjustmentPercent != null && adjustmentPercent > 0) {
      buffer.writeln('');
      buffer.writeln('=== 계산된 보정 ===');
      buffer.writeln(
          '보정 비율: ${adjustmentPercent.toStringAsFixed(0)}% 느리게');
      if (adjustedPaceRange != null) {
        buffer.writeln('보정된 페이스: $adjustedPaceRange');
      }
    }

    buffer.writeln('');
    buffer.writeln('위 날씨 조건과 보정을 참고하여 러너에게 안내 메시지를 작성해주세요.');

    return buffer.toString();
  }
}
