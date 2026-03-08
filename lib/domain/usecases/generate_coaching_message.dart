import 'dart:convert';

import '../../core/utils/pace_adjustment.dart';
import '../../data/models/coaching_message.dart';
import '../../data/services/llm/llm_prompts.dart';
import '../../data/services/llm/llm_provider.dart';
import 'calculate_weekly_stats.dart';

/// 코칭 메시지 생성 유스케이스
///
/// LLM을 활용하여 다양한 유형의 코칭 메시지를 생성합니다.
/// - 주간 리뷰 (weekly_review)
/// - 세션 피드백 (session_feedback)
/// - 날씨 기반 페이스 보정 (pace_adjustment)
/// - 격려 메시지 (encouragement)
class GenerateCoachingMessage {
  final LLMProvider _llmProvider;

  const GenerateCoachingMessage({
    required LLMProvider llmProvider,
  }) : _llmProvider = llmProvider;

  // ---------------------------------------------------------------------------
  // 주간 리뷰 메시지
  // ---------------------------------------------------------------------------

  /// 주간 리뷰 코칭 메시지 생성
  ///
  /// [input] 주간 리뷰 생성에 필요한 데이터
  /// 반환: [CoachingMessage] 생성된 코칭 메시지
  Future<CoachingMessage> generateWeeklyReview(
    WeeklyReviewInput input,
  ) async {
    final context = {
      'week_number': input.weekNumber,
      'phase': input.phase,
      'stats': input.weeklyStats.toContextJson(),
      'plan_name': input.planName,
      if (input.nextWeekPhase != null) 'next_week_phase': input.nextWeekPhase,
      if (input.paceZones != null) 'pace_zones': input.paceZones,
      if (input.sessionDetails != null) 'session_details': input.sessionDetails,
      if (input.nextWeekSummary != null)
        'next_week_summary': input.nextWeekSummary,
    };

    final contextJson = const JsonEncoder.withIndent('  ').convert(context);
    final userPrompt = LLMPrompts.weeklyReviewUserPrompt(contextJson);

    final response = await _llmProvider.generateJson(
      systemPrompt: LLMPrompts.weeklyReviewSystemPrompt,
      userPrompt: userPrompt,
      temperature: 0.8,
      maxTokens: 600,
    );

    final content = _formatWeeklyReviewContent(response.content);

    return CoachingMessage(
      id: '',
      userId: input.userId,
      planId: input.planId,
      weekId: input.weekId,
      messageType: 'weekly_review',
      title: '${input.weekNumber}주차 훈련 리뷰',
      content: content,
      llmModel: response.model,
      llmPromptSnapshot: context,
      tokenUsage: response.tokenUsageToJson(),
      createdAt: DateTime.now(),
    );
  }

  /// JSON 응답을 읽기 좋은 텍스트로 포맷팅
  String _formatWeeklyReviewContent(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final buffer = StringBuffer();

      final summary = json['summary'] as String? ?? '';
      if (summary.isNotEmpty) {
        buffer.writeln(summary);
        buffer.writeln();
      }

      final highlights = json['highlights'] as List<dynamic>?;
      if (highlights != null && highlights.isNotEmpty) {
        buffer.writeln('잘한 점:');
        for (final h in highlights) {
          buffer.writeln('• $h');
        }
        buffer.writeln();
      }

      final improvements = json['improvements'] as List<dynamic>?;
      if (improvements != null && improvements.isNotEmpty) {
        buffer.writeln('개선할 점:');
        for (final i in improvements) {
          buffer.writeln('• $i');
        }
        buffer.writeln();
      }

      final advice = json['next_week_advice'] as String? ?? '';
      if (advice.isNotEmpty) {
        buffer.writeln('다음 주 조언:');
        buffer.writeln(advice);
      }

      return buffer.toString().trim();
    } catch (_) {
      return jsonString;
    }
  }

  // ---------------------------------------------------------------------------
  // 세션 피드백 메시지
  // ---------------------------------------------------------------------------

  /// 개별 세션 피드백 코칭 메시지 생성
  ///
  /// [input] 세션 피드백 생성에 필요한 데이터
  /// 반환: [CoachingMessage] 생성된 코칭 메시지
  Future<CoachingMessage> generateSessionFeedback(
    SessionFeedbackInput input,
  ) async {
    final context = {
      'session_title': input.sessionTitle,
      'session_type': input.sessionType,
      'target_distance_km': input.targetDistanceKm,
      'target_pace': input.targetPace,
      if (input.actualDistanceKm != null)
        'actual_distance_km': input.actualDistanceKm,
      if (input.actualPaceSecondsPerKm != null)
        'actual_pace': _formatPace(input.actualPaceSecondsPerKm!),
      if (input.actualDurationSeconds != null)
        'actual_duration_minutes':
            (input.actualDurationSeconds! / 60).round(),
      'status': input.completionStatus,
      if (input.weatherTempC != null)
        'weather': {
          'temperature_c': input.weatherTempC,
          if (input.weatherHumidity != null)
            'humidity_percent': input.weatherHumidity,
          if (input.weatherCondition != null)
            'condition': input.weatherCondition,
        },
    };

    final contextJson = const JsonEncoder.withIndent('  ').convert(context);

    final response = await _llmProvider.generate(
      systemPrompt: LLMPrompts.sessionFeedbackSystemPrompt,
      userPrompt: '아래 훈련 결과에 대해 간단히 피드백해주세요.\n\n$contextJson',
      temperature: 0.8,
      maxTokens: 200,
    );

    return CoachingMessage(
      id: '',
      userId: input.userId,
      planId: input.planId,
      sessionId: input.sessionId,
      messageType: 'session_feedback',
      title: '${input.sessionTitle} 피드백',
      content: response.content,
      llmModel: response.model,
      llmPromptSnapshot: context,
      tokenUsage: response.tokenUsageToJson(),
      createdAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // 날씨 기반 페이스 보정 메시지
  // ---------------------------------------------------------------------------

  /// 날씨 기반 페이스 보정 코칭 메시지 생성
  ///
  /// [input] 날씨 보정 생성에 필요한 데이터
  /// 반환: [CoachingMessage] 생성된 코칭 메시지
  Future<CoachingMessage> generateWeatherAdjustment(
    WeatherAdjustmentInput input,
  ) async {
    // PaceAdjustment 유틸리티로 보정 비율 계산
    final adjustmentPercent = PaceAdjustment.getAdjustmentPercent(
      temperatureC: input.temperatureC,
      humidityPercent: input.humidityPercent,
      windSpeedMs: input.windSpeedMs,
    );

    // 보정된 페이스 범위 계산
    String? adjustedPaceRange;
    if (input.targetPace != null && adjustmentPercent > 0) {
      final (minPace, maxPace) = PaceAdjustment.adjustPace(
        targetPaceRange: input.targetPace!,
        adjustmentPercent: adjustmentPercent,
      );
      adjustedPaceRange =
          PaceAdjustment.formatAdjustedPaceRange(minPace, maxPace);
    }

    final userPrompt = LLMPrompts.buildPaceAdjustmentPrompt(
      sessionTitle: input.sessionTitle,
      sessionType: input.sessionType,
      targetPace: input.targetPace,
      temperatureC: input.temperatureC,
      humidity: input.humidityPercent ?? 0,
      weatherCondition: input.weatherCondition,
      windSpeedMs: input.windSpeedMs,
      adjustmentPercent: adjustmentPercent,
      adjustedPaceRange: adjustedPaceRange,
    );

    final context = {
      'session_title': input.sessionTitle,
      'session_type': input.sessionType,
      'target_pace': input.targetPace,
      'weather': {
        'temperature_c': input.temperatureC,
        'humidity_percent': input.humidityPercent,
        'condition': input.weatherCondition,
        if (input.windSpeedMs != null) 'wind_speed_ms': input.windSpeedMs,
      },
      'adjustment_percent': adjustmentPercent,
      if (adjustedPaceRange != null) 'adjusted_pace_range': adjustedPaceRange,
    };

    final response = await _llmProvider.generate(
      systemPrompt: LLMPrompts.weatherAdjustmentSystemPrompt,
      userPrompt: userPrompt,
      temperature: 0.7,
      maxTokens: 300,
    );

    return CoachingMessage(
      id: '',
      userId: input.userId,
      planId: input.planId,
      sessionId: input.sessionId,
      messageType: 'pace_adjustment',
      title: '오늘 날씨 기반 페이스 보정',
      content: response.content,
      llmModel: response.model,
      llmPromptSnapshot: context,
      tokenUsage: response.tokenUsageToJson(),
      createdAt: DateTime.now(),
    );
  }

  // ---------------------------------------------------------------------------
  // 헬퍼
  // ---------------------------------------------------------------------------

  static String _formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }
}

// =============================================================================
// 입력 모델
// =============================================================================

/// 주간 리뷰 입력 데이터
class WeeklyReviewInput {
  final String userId;
  final String planId;
  final String weekId;
  final String planName;
  final int weekNumber;
  final String phase;
  final WeeklyStats weeklyStats;
  final String? nextWeekPhase;
  final Map<String, dynamic>? paceZones;
  final List<Map<String, dynamic>>? sessionDetails;
  final String? nextWeekSummary;

  const WeeklyReviewInput({
    required this.userId,
    required this.planId,
    required this.weekId,
    required this.planName,
    required this.weekNumber,
    required this.phase,
    required this.weeklyStats,
    this.nextWeekPhase,
    this.paceZones,
    this.sessionDetails,
    this.nextWeekSummary,
  });
}

/// 세션 피드백 입력 데이터
class SessionFeedbackInput {
  final String userId;
  final String planId;
  final String sessionId;
  final String sessionTitle;
  final String sessionType;
  final double? targetDistanceKm;
  final String? targetPace;
  final double? actualDistanceKm;
  final int? actualPaceSecondsPerKm;
  final int? actualDurationSeconds;
  final String completionStatus;
  final double? weatherTempC;
  final int? weatherHumidity;
  final String? weatherCondition;

  const SessionFeedbackInput({
    required this.userId,
    required this.planId,
    required this.sessionId,
    required this.sessionTitle,
    required this.sessionType,
    this.targetDistanceKm,
    this.targetPace,
    this.actualDistanceKm,
    this.actualPaceSecondsPerKm,
    this.actualDurationSeconds,
    required this.completionStatus,
    this.weatherTempC,
    this.weatherHumidity,
    this.weatherCondition,
  });
}

/// 날씨 기반 페이스 보정 입력 데이터
class WeatherAdjustmentInput {
  final String userId;
  final String? planId;
  final String? sessionId;
  final String sessionTitle;
  final String sessionType;
  final String? targetPace;
  final double temperatureC;
  final int? humidityPercent;
  final String? weatherCondition;
  final double? windSpeedMs;

  const WeatherAdjustmentInput({
    required this.userId,
    this.planId,
    this.sessionId,
    required this.sessionTitle,
    required this.sessionType,
    this.targetPace,
    required this.temperatureC,
    this.humidityPercent,
    this.weatherCondition,
    this.windSpeedMs,
  });
}
