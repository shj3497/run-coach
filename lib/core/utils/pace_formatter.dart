/// 페이스 변환 유틸리티
/// 초/km ↔ M:SS/km 문자열 변환
class PaceFormatter {
  PaceFormatter._();

  /// 초/km → M:SS/km (예: 330 → "5:30/km")
  static String toDisplay(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  /// 초/km → M:SS (단위 없이, 예: 330 → "5:30")
  static String toMMSS(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// M:SS → 초/km (예: "5:30" → 330)
  static int? fromMMSS(String paceString) {
    final cleaned = paceString.replaceAll('/km', '').trim();
    final parts = cleaned.split(':');
    if (parts.length == 2) {
      final minutes = int.tryParse(parts[0]);
      final seconds = int.tryParse(parts[1]);
      if (minutes != null && seconds != null) {
        return minutes * 60 + seconds;
      }
    }
    return null;
  }
}
