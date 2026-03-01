import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../common/widgets/skeleton.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../providers/strava_auth_provider.dart';
import 'providers/my_page_provider.dart';

/// C-4 마이페이지
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myPageProfileProvider);
    final isStravaConnected = ref.watch(isStravaConnectedProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '마이페이지',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),

              // 프로필 헤더
              profileAsync.when(
                loading: () => const MyPageSkeleton(),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => _buildProfileHeader(context, profile),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 메뉴 그룹 1: 훈련 관련
              _buildMenuGroup(
                context,
                items: [
                  _MenuItem(
                    icon: Icons.list_alt_rounded,
                    label: '내 플랜 관리',
                    onTap: () {
                      // TODO: D-6 플랜 상세/관리 목록으로 이동
                    },
                  ),
                  _MenuItem(
                    icon: Icons.emoji_events_rounded,
                    label: '대회 기록',
                    onTap: () {
                      // TODO: D-7 대회 기록 관리 (Phase 6)
                    },
                  ),
                  _MenuItem(
                    icon: Icons.bar_chart_rounded,
                    label: '통계',
                    onTap: () {
                      // TODO: 통계 화면 (Phase 6)
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // 메뉴 그룹 2: 연동/설정
              _buildMenuGroup(
                context,
                items: [
                  _MenuItem(
                    icon: Icons.link_rounded,
                    label: isStravaConnected
                        ? 'Strava 연동 해제'
                        : 'Strava 연동',
                    onTap: () {
                      if (isStravaConnected) {
                        _showStravaDisconnectDialog(context, ref);
                      } else {
                        ref
                            .read(stravaAuthProvider.notifier)
                            .startOAuthFlow();
                      }
                    },
                  ),
                  _MenuItem(
                    icon: Icons.notifications_none_rounded,
                    label: '알림 설정',
                    onTap: () {
                      // TODO: 알림 설정 (Phase 6)
                    },
                  ),
                  _MenuItem(
                    icon: Icons.person_outline_rounded,
                    label: '프로필 수정',
                    onTap: () {
                      // TODO: 프로필 수정 화면
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // 메뉴 그룹 3: 기타
              _buildMenuGroup(
                context,
                items: [
                  _MenuItem(
                    icon: Icons.description_outlined,
                    label: '이용약관',
                    onTap: () {
                      // TODO: 이용약관 화면
                    },
                  ),
                  _MenuItem(
                    icon: Icons.lock_outline_rounded,
                    label: '개인정보처리방침',
                    onTap: () {
                      // TODO: 개인정보 화면
                    },
                  ),
                  _MenuItem(
                    icon: Icons.logout_rounded,
                    label: '로그아웃',
                    isDestructive: true,
                    onTap: () {
                      _showLogoutDialog(context);
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.xxl),

              // 앱 버전
              Text(
                'v1.0.0',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  /// 프로필 헤더
  Widget _buildProfileHeader(BuildContext context, MyPageProfile profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          children: [
            // 프로필 아바타
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.primary(context).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person_rounded,
                size: 36,
                color: AppColors.primary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // 닉네임
            Text(
              profile.nickname,
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            // VDOT 점수
            if (profile.currentVdot != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary(context).withValues(alpha: 0.1),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.badgeRadius),
                ),
                child: Text(
                  'VDOT ${profile.currentVdot!.toStringAsFixed(1)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 메뉴 그룹
  Widget _buildMenuGroup(
    BuildContext context, {
    required List<_MenuItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isLast = index == items.length - 1;

            return Column(
              children: [
                _buildMenuRow(context, item),
                if (!isLast)
                  Divider(
                    height: 0.5,
                    indent: AppSpacing.cardPadding + 24 + AppSpacing.md,
                    color: AppColors.divider(context),
                  ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  /// 메뉴 행
  Widget _buildMenuRow(BuildContext context, _MenuItem item) {
    return GestureDetector(
      onTap: item.onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              size: 24,
              color: item.isDestructive
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: AppTypography.bodyLarge.copyWith(
                  color: item.isDestructive
                      ? AppColors.error
                      : AppColors.textPrimary(context),
                ),
              ),
            ),
            if (!item.isDestructive)
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
          ],
        ),
      ),
    );
  }

  /// Strava 연동 해제 확인 다이얼로그
  void _showStravaDisconnectDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text(
          'Strava 연동 해제',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          'Strava 연동을 해제하시겠습니까?\n해제 후에도 기존 동기화된 기록은 유지됩니다.',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '취소',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              ref.read(stravaAuthProvider.notifier).disconnect();
            },
            child: Text(
              '연동 해제',
              style: AppTypography.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 로그아웃 확인 다이얼로그
  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text(
          '로그아웃',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          '정말 로그아웃 하시겠습니까?',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '취소',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              // TODO: 실제 로그아웃 처리
              context.go('/login');
            },
            child: Text(
              '로그아웃',
              style: AppTypography.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 메뉴 아이템 데이터
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isDestructive;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
    this.isDestructive = false,
  });
}
