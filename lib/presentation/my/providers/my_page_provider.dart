import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_providers.dart';
import '../../providers/data_providers.dart';

// ─── Data Models ───

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

/// 마이페이지 프로필 Provider (실제 데이터)
final myPageProfileProvider = FutureProvider<MyPageProfile>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) {
    return const MyPageProfile(nickname: '러너');
  }

  final userRepo = ref.watch(userRepositoryProvider);
  final raceRecordRepo = ref.watch(raceRecordRepositoryProvider);

  // 닉네임 조회
  String nickname = '러너';
  try {
    final profile = await userRepo.getProfile(user.id);
    if (profile != null) {
      nickname = profile.nickname;
    }
  } catch (_) {}

  // 최신 VDOT 조회
  double? currentVdot;
  try {
    currentVdot = await raceRecordRepo.getLatestVdot(user.id);
  } catch (_) {}

  return MyPageProfile(
    nickname: nickname,
    currentVdot: currentVdot,
  );
});
