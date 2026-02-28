import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Mock Data Models ───

/// 마이페이지 프로필 데이터
class MyPageProfile {
  final String nickname;
  final double? currentVdot;
  final String? profileImageUrl;

  const MyPageProfile({
    required this.nickname,
    this.currentVdot,
    this.profileImageUrl,
  });
}

// ─── Providers ───

/// 마이페이지 프로필 Provider (mock)
final myPageProfileProvider = FutureProvider<MyPageProfile>((ref) async {
  // Phase 3: Repository 완성 전까지 mock 데이터
  return const MyPageProfile(
    nickname: '러너',
    currentVdot: 42.1,
  );
});
