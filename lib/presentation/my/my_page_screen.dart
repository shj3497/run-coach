import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../common/widgets/skeleton.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'providers/my_page_provider.dart';

/// C-4 마이페이지
class MyPageScreen extends ConsumerWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(myPageProfileProvider);

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
                    onTap: () => context.push('/my/plans'),
                  ),
                  _MenuItem(
                    icon: Icons.emoji_events_rounded,
                    label: '대회 기록',
                    onTap: () => context.push('/my/race-records'),
                  ),
                  _MenuItem(
                    icon: Icons.bar_chart_rounded,
                    label: '통계',
                    onTap: () {
                      // TODO: 통계 화면
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // 메뉴 그룹 2: 기타
              _buildMenuGroup(
                context,
                items: [
                  _MenuItem(
                    icon: Icons.settings_outlined,
                    label: '설정',
                    onTap: () => context.push('/my/settings'),
                  ),
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
              color: AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                item.label,
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
            ),
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
}

/// 메뉴 아이템 데이터
class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.label,
    this.onTap,
  });
}
