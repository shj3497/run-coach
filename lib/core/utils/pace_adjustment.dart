import 'dart:math';

import 'pace_formatter.dart';

/// 날씨 기반 페이스 보정 유틸리티
///
/// 기온, 습도, 풍속에 따라 목표 페이스를 보정합니다.
/// 순수 로직만 포함하며 LLM 호출 없음.
///
/// 기준: Jack Daniels' Running Formula의 환경 보정 가이드라인 참고
/// - 12-15도C가 최적 조건 (보정 없음)
/// - 고온/저온/습도/풍속에 따라 페이스를 늦춤
class PaceAdjustment {
  PaceAdjustment._();

  /// 기온에 따른 페이스 보정 비율(%) 반환
  ///
  /// 반환: 보정 비율 (%). 0이면 보정 불필요, 양수이면 느려져야 함.
  static double getAdjustmentPercent({
    required double temperatureC,
    int? humidityPercent,
    double? windSpeedMs,
  }) {
    double percent = 0.0;

    if (temperatureC >= 12 && temperatureC <= 15) {
      percent = 0.0;
    } else if (temperatureC > 15 && temperatureC <= 20) {
      percent = _lerp(temperatureC, 15, 20, 0, 3);
    } else if (temperatureC > 20 && temperatureC <= 25) {
      percent = _lerp(temperatureC, 20, 25, 3, 5);
    } else if (temperatureC > 25 && temperatureC <= 30) {
      percent = _lerp(temperatureC, 25, 30, 5, 8);
    } else if (temperatureC > 30) {
      percent = _lerp(temperatureC, 30, 40, 8, 12).clamp(8.0, 12.0);
    } else if (temperatureC >= 5 && temperatureC < 12) {
      percent = _lerp(temperatureC, 12, 5, 0, 1);
    } else if (temperatureC >= 0 && temperatureC < 5) {
      percent = _lerp(temperatureC, 5, 0, 1, 3);
    } else {
      percent = _lerp(temperatureC, 0, -10, 3, 5).clamp(3.0, 5.0);
    }

    if (humidityPercent != null && humidityPercent >= 80) {
      percent += 2.0;
    }

    if (windSpeedMs != null && windSpeedMs >= 8.0) {
      percent += 2.0;
    }

    return (percent * 10).round() / 10.0;
  }

  /// 목표 페이스 범위에 보정 적용
  ///
  /// 반환: (보정된 최소 페이스 초/km, 보정된 최대 페이스 초/km)
  static (int, int) adjustPace({
    required String targetPaceRange,
    required double adjustmentPercent,
  }) {
    if (adjustmentPercent <= 0) {
      return _parsePaceRange(targetPaceRange);
    }

    final (minPace, maxPace) = _parsePaceRange(targetPaceRange);
    final factor = 1.0 + (adjustmentPercent / 100.0);

    final adjustedMin = (minPace * factor).round();
    final adjustedMax = (maxPace * factor).round();

    return (adjustedMin, adjustedMax);
  }

  /// 보정된 페이스 범위를 "M:SS-M:SS/km" 문자열로 반환
  static String formatAdjustedPaceRange(
    int minPaceSeconds,
    int maxPaceSeconds,
  ) {
    final minStr = PaceFormatter.toMMSS(minPaceSeconds);
    final maxStr = PaceFormatter.toMMSS(maxPaceSeconds);

    if (minPaceSeconds == maxPaceSeconds) {
      return '$minStr/km';
    }
    return '$minStr-$maxStr/km';
  }

  /// 보정 요약 문자열 생성 (UI 표시용)
  static String getSummary({
    required double temperatureC,
    int? humidityPercent,
    double? windSpeedMs,
    required double adjustmentPercent,
  }) {
    if (adjustmentPercent <= 0) {
      return '현재 날씨는 러닝에 최적입니다. 목표 페이스대로 달리세요.';
    }

    final buffer = StringBuffer();
    buffer.write('기온 ${temperatureC.toStringAsFixed(0)}°C');

    if (humidityPercent != null && humidityPercent >= 80) {
      buffer.write(', 습도 $humidityPercent%');
    }

    if (windSpeedMs != null && windSpeedMs >= 8.0) {
      buffer.write(', 풍속 ${windSpeedMs.toStringAsFixed(0)}m/s');
    }

    buffer.write(
        ' → 페이스를 약 ${adjustmentPercent.toStringAsFixed(0)}% 늦추세요');

    return buffer.toString();
  }

  // ---------------------------------------------------------------------------
  // 헬퍼
  // ---------------------------------------------------------------------------

  static (int, int) _parsePaceRange(String paceRange) {
    final cleaned = paceRange.replaceAll('/km', '').trim();

    if (cleaned.contains('-')) {
      final parts = cleaned.split('-');
      final minPace = PaceFormatter.fromMMSS(parts[0].trim());
      final maxPace = PaceFormatter.fromMMSS(parts[1].trim());

      if (minPace != null && maxPace != null) {
        return (min(minPace, maxPace), max(minPace, maxPace));
      }
    }

    final pace = PaceFormatter.fromMMSS(cleaned);
    if (pace != null) {
      return (pace, pace);
    }

    return (360, 360);
  }

  static double _lerp(
    double value,
    double fromMin,
    double fromMax,
    double toMin,
    double toMax,
  ) {
    if (fromMax == fromMin) return toMin;
    final t = (value - fromMin) / (fromMax - fromMin);
    return toMin + t * (toMax - toMin);
  }
}
