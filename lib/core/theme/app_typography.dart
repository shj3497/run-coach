import 'package:flutter/material.dart';

/// DESIGN_SYSTEM.md 기반 타이포그래피 스케일
/// 폰트: SF Pro (iOS 시스템, 영문/숫자)
class AppTypography {
  AppTypography._();

  static const String _fontFamily = '.SF Pro Text';

  // Display — 스플래시 앱 이름
  static const TextStyle display = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    fontWeight: FontWeight.bold,
    height: 1.2,
  );

  // H1 — 화면 제목
  static const TextStyle h1 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.3,
  );

  // H2 — 섹션 제목
  static const TextStyle h2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );

  // H3 — 카드 제목
  static const TextStyle h3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
  );

  // Body Large — 코칭 메시지, 설명
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  // Body — 일반 텍스트
  static const TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.normal,
    height: 1.5,
  );

  // Body Small — 부가 정보, 라벨
  static const TextStyle bodySmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.4,
  );

  // Caption — 날짜, 메타 정보
  static const TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.normal,
    height: 1.3,
  );

  // Stats Large — 거리, 페이스 큰 숫자
  static const TextStyle statsLarge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 36,
    fontWeight: FontWeight.bold,
    height: 1.1,
  );

  // Stats Medium — 통계 숫자
  static const TextStyle statsMedium = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
}
