import 'dart:math';

/// VDOT 계산기 (Jack Daniels' Running Formula 기반)
///
/// 대회 기록(거리 + 시간)으로부터 VDOT 점수를 산출하고,
/// VDOT에서 훈련 페이스 존(E/M/T/I/R)을 계산합니다.
///
/// 참고: Daniels, J. & Gilbert, J. "Oxygen Power" (1979)
///       Daniels, J. "Daniels' Running Formula" (3rd ed.)
class VdotCalculator {
  VdotCalculator._();

  // ---------------------------------------------------------------------------
  // 1. VDOT 점수 계산
  // ---------------------------------------------------------------------------

  /// 대회 기록으로 VDOT 점수 계산
  ///
  /// [distanceKm] 대회 거리 (km)
  /// [finishTimeSeconds] 완주 시간 (초)
  /// 반환: VDOT 점수 (소수점 1자리), 범위 밖이면 null
  static double? calculate({
    required double distanceKm,
    required int finishTimeSeconds,
  }) {
    if (distanceKm <= 0 || finishTimeSeconds <= 0) return null;

    final distanceMeters = distanceKm * 1000;
    final timeMinutes = finishTimeSeconds / 60.0;

    // 속도 (m/min)
    final velocity = distanceMeters / timeMinutes;

    // VO2 계산 (산소 소비량 추정, ml/kg/min)
    // Daniels & Gilbert regression
    final vo2 = _velocityToVo2(velocity);

    // %VO2max 계산 (시간에 따른 지속 가능 비율)
    final percentMax = _timeToPercentMax(timeMinutes);

    if (percentMax <= 0) return null;

    final vdot = vo2 / percentMax;

    // 합리적 범위 체크 (VDOT 20~85)
    if (vdot < 20 || vdot > 85) return null;

    return (vdot * 10).round() / 10.0;
  }

  // ---------------------------------------------------------------------------
  // 2. 페이스 존 계산
  // ---------------------------------------------------------------------------

  /// VDOT 점수에서 훈련 페이스 존 계산 (표시용 문자열)
  ///
  /// 반환: {'E': '6:00-6:30', 'M': '5:15', 'T': '4:55', 'I': '4:32', 'R': '4:17'}
  static Map<String, String> getPaceZones(double vdot) {
    final zones = getPaceZonesInSeconds(vdot);

    return {
      'E': '${_formatPace(zones['E_fast']!)}-${_formatPace(zones['E_slow']!)}',
      'M': _formatPace(zones['M']!),
      'T': _formatPace(zones['T']!),
      'I': _formatPace(zones['I']!),
      'R': _formatPace(zones['R']!),
    };
  }

  /// VDOT 점수에서 구조화된 페이스 존 반환 (LLM context 등에 사용)
  ///
  /// 반환: PaceZones 객체
  static PaceZones getPaceZonesStructured(double vdot) {
    final zones = getPaceZonesInSeconds(vdot);

    return PaceZones(
      easySlowPace: zones['E_slow']!,
      easyFastPace: zones['E_fast']!,
      marathonPace: zones['M']!,
      thresholdPace: zones['T']!,
      intervalPace: zones['I']!,
      repetitionPace: zones['R']!,
    );
  }

  /// VDOT 점수에서 각 존의 페이스를 초/km 단위로 반환
  ///
  /// E (Easy): 59~74% VO2max
  /// M (Marathon): ~75~84% VO2max -- 약 80%
  /// T (Threshold): ~83~88% VO2max -- 약 88%
  /// I (Interval): ~95~100% VO2max -- 약 98%
  /// R (Repetition): ~105% VO2max
  static Map<String, int> getPaceZonesInSeconds(double vdot) {
    return {
      'E_slow': _vdotToPaceSecondsPerKm(vdot, 0.59),
      'E_fast': _vdotToPaceSecondsPerKm(vdot, 0.74),
      'M': _vdotToPaceSecondsPerKm(vdot, 0.80),
      'T': _vdotToPaceSecondsPerKm(vdot, 0.88),
      'I': _vdotToPaceSecondsPerKm(vdot, 0.98),
      'R': _vdotToPaceSecondsPerKm(vdot, 1.05),
    };
  }

  // ---------------------------------------------------------------------------
  // 3. 예상 레이스 시간 계산
  // ---------------------------------------------------------------------------

  /// VDOT 점수에서 주어진 거리의 예상 완주 시간 계산 (초)
  ///
  /// [vdot] VDOT 점수
  /// [distanceKm] 예상할 거리 (km)
  /// 반환: 예상 완주 시간 (초), 계산 불가 시 null
  static int? estimateRaceTime({
    required double vdot,
    required double distanceKm,
  }) {
    if (vdot <= 0 || distanceKm <= 0) return null;

    // 이진 탐색으로 주어진 VDOT을 만족하는 시간을 찾음
    // 범위: 1분 ~ 6시간
    double lowMinutes = 1.0;
    double highMinutes = 360.0;

    final distanceMeters = distanceKm * 1000;

    for (int i = 0; i < 100; i++) {
      final midMinutes = (lowMinutes + highMinutes) / 2;
      final velocity = distanceMeters / midMinutes;
      final vo2 = _velocityToVo2(velocity);
      final percentMax = _timeToPercentMax(midMinutes);

      if (percentMax <= 0) {
        lowMinutes = midMinutes;
        continue;
      }

      final calculatedVdot = vo2 / percentMax;

      if ((calculatedVdot - vdot).abs() < 0.01) {
        return (midMinutes * 60).round();
      }

      if (calculatedVdot > vdot) {
        // 현재 시간이 너무 짧음 (빠르게 달림) -> 시간 늘림
        lowMinutes = midMinutes;
      } else {
        // 현재 시간이 너무 김 (느리게 달림) -> 시간 줄임
        highMinutes = midMinutes;
      }
    }

    final midMinutes = (lowMinutes + highMinutes) / 2;
    return (midMinutes * 60).round();
  }

  /// VDOT 점수에서 표준 거리별 예상 레이스 시간 반환 (초)
  ///
  /// 반환: {'5K': 1296, '10K': 2688, 'Half': 5927, 'Full': 12401}
  static Map<String, int?> estimateAllRaceTimes(double vdot) {
    return {
      '5K': estimateRaceTime(vdot: vdot, distanceKm: 5.0),
      '10K': estimateRaceTime(vdot: vdot, distanceKm: 10.0),
      'Half': estimateRaceTime(vdot: vdot, distanceKm: 21.0975),
      'Full': estimateRaceTime(vdot: vdot, distanceKm: 42.195),
    };
  }

  /// VDOT 점수에서 표준 거리별 예상 레이스 시간 반환 (표시용 문자열)
  ///
  /// 반환: {'5K': '21:36', '10K': '44:48', 'Half': '1:38:47', 'Full': '3:26:41'}
  static Map<String, String> estimateAllRaceTimesFormatted(double vdot) {
    final times = estimateAllRaceTimes(vdot);
    return times.map((key, value) {
      if (value == null) return MapEntry(key, '-');
      return MapEntry(key, _formatTime(value));
    });
  }

  // ---------------------------------------------------------------------------
  // 4. 편의 메서드
  // ---------------------------------------------------------------------------

  /// 표준 대회 거리 (km)
  static const Map<String, double> standardDistances = {
    '5K': 5.0,
    '10K': 10.0,
    'Half': 21.0975,
    'Full': 42.195,
  };

  /// 표준 대회 거리 한글명
  static const Map<String, String> standardDistanceLabels = {
    '5K': '5K',
    '10K': '10K',
    'Half': '하프마라톤',
    'Full': '풀마라톤',
  };

  /// 거리(km)에 해당하는 표준 거리 키를 반환
  ///
  /// 예: 21.0975 -> 'Half', 42.195 -> 'Full'
  /// 표준 거리가 아니면 null
  static String? getStandardDistanceKey(double distanceKm) {
    for (final entry in standardDistances.entries) {
      if ((entry.value - distanceKm).abs() < 0.01) {
        return entry.key;
      }
    }
    return null;
  }

  /// 두 대회 기록 중 더 신뢰할 수 있는 VDOT을 반환
  ///
  /// 일반적으로 더 긴 거리의 기록이 VDOT 추정에 더 신뢰할 수 있음.
  /// 같은 거리라면 더 최근 기록을 우선.
  static double? selectBestVdot(List<RaceRecordForVdot> records) {
    if (records.isEmpty) return null;

    // 거리 기준 내림차순 정렬 (같은 거리면 최신 우선)
    final sorted = List<RaceRecordForVdot>.from(records)
      ..sort((a, b) {
        final distCompare = b.distanceKm.compareTo(a.distanceKm);
        if (distCompare != 0) return distCompare;
        return b.raceDate.compareTo(a.raceDate);
      });

    for (final record in sorted) {
      final vdot = calculate(
        distanceKm: record.distanceKm,
        finishTimeSeconds: record.finishTimeSeconds,
      );
      if (vdot != null) return vdot;
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // 내부 헬퍼 메서드
  // ---------------------------------------------------------------------------

  /// 속도(m/min) -> VO2 (ml/kg/min) 변환
  ///
  /// Daniels & Gilbert regression:
  /// VO2 = -4.60 + 0.182258 * v + 0.000104 * v^2
  static double _velocityToVo2(double velocity) {
    return -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity;
  }

  /// 시간(분) -> %VO2max (지속 가능 비율) 변환
  ///
  /// Daniels & Gilbert regression:
  /// %VO2max = 0.8 + 0.1894393 * e^(-0.012778 * t) + 0.2989558 * e^(-0.1932605 * t)
  static double _timeToPercentMax(double timeMinutes) {
    return 0.8 +
        0.1894393 * exp(-0.012778 * timeMinutes) +
        0.2989558 * exp(-0.1932605 * timeMinutes);
  }

  /// %VO2max -> 페이스(초/km) 변환
  ///
  /// 주어진 VDOT과 %VO2max에서 해당 강도의 페이스를 계산.
  /// VO2 = VDOT * percentVo2Max 에서 역으로 속도를 구함.
  static int _vdotToPaceSecondsPerKm(double vdot, double percentVo2Max) {
    final vo2 = vdot * percentVo2Max;
    // 역계산: vo2 = -4.60 + 0.182258*v + 0.000104*v^2
    // 0.000104*v^2 + 0.182258*v + (-4.60 - vo2) = 0
    const a = 0.000104;
    const b = 0.182258;
    final c = -4.60 - vo2;

    final discriminant = b * b - 4 * a * c;
    if (discriminant < 0) return 0;

    final velocity = (-b + sqrt(discriminant)) / (2 * a); // m/min
    if (velocity <= 0) return 0;

    // m/min -> 초/km
    final secondsPerKm = (1000 / velocity) * 60;
    return secondsPerKm.round();
  }

  /// 초/km -> M:SS 형식
  static String _formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 초 -> 적절한 시간 형식 (HH:MM:SS 또는 MM:SS)
  static String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}

/// VDOT 선택을 위한 대회 기록 경량 모델
class RaceRecordForVdot {
  final double distanceKm;
  final int finishTimeSeconds;
  final DateTime raceDate;

  const RaceRecordForVdot({
    required this.distanceKm,
    required this.finishTimeSeconds,
    required this.raceDate,
  });
}

/// 페이스 존 구조체
///
/// 각 존의 페이스를 초/km 단위로 제공합니다.
class PaceZones {
  /// E (Easy) 존 느린 쪽 페이스 (초/km)
  final int easySlowPace;

  /// E (Easy) 존 빠른 쪽 페이스 (초/km)
  final int easyFastPace;

  /// M (Marathon) 존 페이스 (초/km)
  final int marathonPace;

  /// T (Threshold) 존 페이스 (초/km)
  final int thresholdPace;

  /// I (Interval) 존 페이스 (초/km)
  final int intervalPace;

  /// R (Repetition) 존 페이스 (초/km)
  final int repetitionPace;

  const PaceZones({
    required this.easySlowPace,
    required this.easyFastPace,
    required this.marathonPace,
    required this.thresholdPace,
    required this.intervalPace,
    required this.repetitionPace,
  });

  /// LLM context용 JSON 변환
  Map<String, dynamic> toContextJson() {
    return {
      'E': {
        'min_pace': _formatPace(easyFastPace),
        'max_pace': _formatPace(easySlowPace),
        'min_pace_seconds': easyFastPace,
        'max_pace_seconds': easySlowPace,
      },
      'M': {
        'pace': _formatPace(marathonPace),
        'pace_seconds': marathonPace,
      },
      'T': {
        'pace': _formatPace(thresholdPace),
        'pace_seconds': thresholdPace,
      },
      'I': {
        'pace': _formatPace(intervalPace),
        'pace_seconds': intervalPace,
      },
      'R': {
        'pace': _formatPace(repetitionPace),
        'pace_seconds': repetitionPace,
      },
    };
  }

  /// DB 저장용 간단한 JSON 변환
  Map<String, dynamic> toJson() {
    return {
      'E_slow': easySlowPace,
      'E_fast': easyFastPace,
      'M': marathonPace,
      'T': thresholdPace,
      'I': intervalPace,
      'R': repetitionPace,
    };
  }

  /// DB에서 복원
  factory PaceZones.fromJson(Map<String, dynamic> json) {
    return PaceZones(
      easySlowPace: json['E_slow'] as int,
      easyFastPace: json['E_fast'] as int,
      marathonPace: json['M'] as int,
      thresholdPace: json['T'] as int,
      intervalPace: json['I'] as int,
      repetitionPace: json['R'] as int,
    );
  }

  static String _formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  @override
  String toString() {
    return 'PaceZones(E: ${_formatPace(easyFastPace)}-${_formatPace(easySlowPace)}, '
        'M: ${_formatPace(marathonPace)}, T: ${_formatPace(thresholdPace)}, '
        'I: ${_formatPace(intervalPace)}, R: ${_formatPace(repetitionPace)})';
  }
}
