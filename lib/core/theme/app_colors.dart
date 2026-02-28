import 'package:flutter/material.dart';

/// DESIGN_SYSTEM.md 기반 컬러 정의
/// 라이트/다크 모드 모두 지원
class AppColors {
  AppColors._();

  // ─── Primary (Indigo Blue) ───
  static const Color primaryLight = Color(0xFF5856D6);
  static const Color primaryDark = Color(0xFF7B79FF);
  static const Color primaryDarkPressed = Color(0xFF4240A8);
  static const Color primaryLightPressed = Color(0xFF5856D6);

  static Color primaryLightBg = const Color(0xFF5856D6).withOpacity(0.12);
  static Color primaryDarkBg = const Color(0xFF7B79FF).withOpacity(0.15);

  // ─── Background ───
  static const Color backgroundLight = Color(0xFFF2F2F7);
  static const Color backgroundDark = Color(0xFF000000);

  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1C1C1E);

  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color surfaceElevatedDark = Color(0xFF2C2C2E);

  // ─── Text ───
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  static const Color textSecondary = Color(0xFF8E8E93);

  static const Color textDisabledLight = Color(0xFFC7C7CC);
  static const Color textDisabledDark = Color(0xFF48484A);

  // ─── Status Colors (공통) ───
  static const Color success = Color(0xFF34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color info = primaryLight;

  // ─── Social Login Colors ───
  static const Color appleLight = Color(0xFF000000);
  static const Color appleDark = Color(0xFFFFFFFF);

  static const Color googleLight = Color(0xFFFFFFFF);
  static const Color googleDark = Color(0xFF1C1C1E);

  static const Color kakao = Color(0xFFFEE500);

  // ─── 모드별 컬러 접근 헬퍼 ───
  static Color primary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? primaryLight
          : primaryDark;

  static Color primaryPressed(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? primaryDarkPressed
          : primaryLightPressed;

  static Color primaryBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? primaryLightBg
          : primaryDarkBg;

  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? backgroundLight
          : backgroundDark;

  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? surfaceLight
          : surfaceDark;

  static Color surfaceElevated(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? surfaceElevatedLight
          : surfaceElevatedDark;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? textPrimaryLight
          : textPrimaryDark;

  static Color textDisabled(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? textDisabledLight
          : textDisabledDark;

  // ─── Divider ───
  static const Color dividerLight = Color(0xFFE5E5EA);
  static const Color dividerDark = Color(0xFF38383A);

  static Color divider(BuildContext context) =>
      Theme.of(context).brightness == Brightness.light
          ? dividerLight
          : dividerDark;

}
