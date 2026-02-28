/// DESIGN_SYSTEM.md 기반 스페이싱 토큰
class AppSpacing {
  AppSpacing._();

  // ─── Spacing Tokens ───
  static const double xs = 4.0;   // 아이콘과 텍스트 사이
  static const double sm = 8.0;   // 카드 내부 요소 간격
  static const double md = 12.0;  // 카드 내부 패딩
  static const double lg = 16.0;  // 카드 외부 간격, 섹션 간격
  static const double xl = 24.0;  // 섹션 간 큰 간격
  static const double xxl = 32.0; // 화면 상단 여백

  // ─── Layout ───
  static const double screenPadding = 16.0;    // 화면 좌우 패딩
  static const double cardRadius = 16.0;       // 카드 radius
  static const double buttonRadius = 12.0;     // 버튼 radius
  static const double badgeRadius = 8.0;       // 배지 radius
  static const double cardPadding = 16.0;      // 카드 내부 패딩
  static const double listItemHeight = 64.0;   // 리스트 아이템 높이 (56~72 중간값)
}
