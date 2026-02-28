/// 시간 변환 유틸리티
/// 초 단위 ↔ HH:MM:SS / MM:SS 문자열 변환
class TimeFormatter {
  TimeFormatter._();

  /// 초 → HH:MM:SS (예: 7200 → "2:00:00")
  static String toHHMMSS(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 초 → MM:SS (예: 330 → "5:30")
  static String toMMSS(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// HH:MM:SS → 초 (예: "2:00:00" → 7200)
  static int? fromHHMMSS(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 3) {
      final hours = int.tryParse(parts[0]);
      final minutes = int.tryParse(parts[1]);
      final seconds = int.tryParse(parts[2]);
      if (hours != null && minutes != null && seconds != null) {
        return hours * 3600 + minutes * 60 + seconds;
      }
    }
    return null;
  }

  /// MM:SS → 초 (예: "5:30" → 330)
  static int? fromMMSS(String timeString) {
    final parts = timeString.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) {
        return minutes * 60 + seconds;
      }
    }
    return null;
  }

  /// 초를 사람이 읽기 쉬운 형태로 (1시간 이상이면 HH:MM:SS, 미만이면 MM:SS)
  static String toReadable(int totalSeconds) {
    if (totalSeconds >= 3600) {
      return toHHMMSS(totalSeconds);
    }
    return toMMSS(totalSeconds);
  }
}
