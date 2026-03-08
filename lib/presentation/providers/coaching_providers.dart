import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/pace_adjustment.dart';
import '../../data/services/weather_service.dart';
import '../../domain/usecases/generate_coaching_message.dart';
import '../auth/providers/auth_providers.dart';
import 'data_providers.dart';

// -----------------------------------------------------------------------------
// 코칭 메시지 생성 유스케이스 Provider
// -----------------------------------------------------------------------------

final generateCoachingMessageProvider =
    Provider<GenerateCoachingMessage>((ref) {
  return GenerateCoachingMessage(llmProvider: ref.watch(llmProviderProvider));
});

// -----------------------------------------------------------------------------
// 날씨 기반 페이스 보정 결과 모델
// -----------------------------------------------------------------------------

class PaceAdjustmentResult {
  final double adjustmentPercent;
  final int? adjustedMinPace;
  final int? adjustedMaxPace;
  final String? adjustedPaceRange;
  final String summary;
  final WeatherData weather;

  const PaceAdjustmentResult({
    required this.adjustmentPercent,
    this.adjustedMinPace,
    this.adjustedMaxPace,
    this.adjustedPaceRange,
    required this.summary,
    required this.weather,
  });

  bool get needsAdjustment => adjustmentPercent > 0;
}

// -----------------------------------------------------------------------------
// 날씨 기반 페이스 보정 Provider
// -----------------------------------------------------------------------------

/// 세션의 날씨 기반 페이스 보정 계산
///
/// (sessionId, targetPaceRange) 튜플을 키로 사용
final weatherPaceAdjustmentProvider = FutureProvider.family<
    PaceAdjustmentResult?, ({String sessionId, String? targetPace})>(
  (ref, params) async {
    final weather = await ref.watch(currentWeatherProvider.future);
    if (weather == null) return null;

    final adjustmentPercent = PaceAdjustment.getAdjustmentPercent(
      temperatureC: weather.temperatureC,
      humidityPercent: weather.humidityPercent,
      windSpeedMs: weather.windSpeedMs,
    );

    int? adjustedMin;
    int? adjustedMax;
    String? adjustedRange;

    if (params.targetPace != null && adjustmentPercent > 0) {
      final (min, max) = PaceAdjustment.adjustPace(
        targetPaceRange: params.targetPace!,
        adjustmentPercent: adjustmentPercent,
      );
      adjustedMin = min;
      adjustedMax = max;
      adjustedRange = PaceAdjustment.formatAdjustedPaceRange(min, max);
    }

    final summary = PaceAdjustment.getSummary(
      temperatureC: weather.temperatureC,
      humidityPercent: weather.humidityPercent,
      windSpeedMs: weather.windSpeedMs,
      adjustmentPercent: adjustmentPercent,
    );

    return PaceAdjustmentResult(
      adjustmentPercent: adjustmentPercent,
      adjustedMinPace: adjustedMin,
      adjustedMaxPace: adjustedMax,
      adjustedPaceRange: adjustedRange,
      summary: summary,
      weather: weather,
    );
  },
);

// -----------------------------------------------------------------------------
// 주간 리뷰 Provider
// -----------------------------------------------------------------------------

/// 주간 리뷰 조회/생성 Provider
///
/// DB에 이미 생성된 리뷰가 있으면 반환, 없으면 null 반환
/// (자동 생성하지 않음 — UI에서 명시적 생성 버튼으로 트리거)
final weeklyReviewProvider =
    FutureProvider.family<String?, String>((ref, weekId) async {
  final coachingRepo = ref.watch(coachingRepositoryProvider);
  final existing = await coachingRepo.getWeeklyReview(weekId);
  return existing?.content;
});

// -----------------------------------------------------------------------------
// 세션 피드백 Provider
// -----------------------------------------------------------------------------

/// 세션 피드백 조회 Provider
///
/// DB에 이미 생성된 피드백이 있으면 반환
final sessionFeedbackProvider =
    FutureProvider.family<String?, String>((ref, sessionId) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final coachingRepo = ref.watch(coachingRepositoryProvider);
  final existing = await coachingRepo.getSessionFeedback(sessionId);
  return existing?.content;
});
