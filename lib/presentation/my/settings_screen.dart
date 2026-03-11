import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../providers/strava_auth_provider.dart';
import '../providers/theme_provider.dart';

/// D-8 설정 화면
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStravaConnected = ref.watch(isStravaConnectedProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '설정',
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

              // 연동 관리
              _buildSectionHeader(context, '연동 관리'),
              _buildMenuGroup(context, children: [
                _buildMenuRow(
                  context,
                  icon: Icons.link_rounded,
                  label: 'Strava 연동',
                  trailing: Text(
                    isStravaConnected ? '연결됨' : '연결하기',
                    style: AppTypography.body.copyWith(
                      color: isStravaConnected
                          ? AppColors.success
                          : AppColors.primary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
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
              ]),

              const SizedBox(height: AppSpacing.lg),

              // 앱 설정
              _buildSectionHeader(context, '앱 설정'),
              _buildMenuGroup(context, children: [
                _buildMenuRow(
                  context,
                  icon: Icons.dark_mode_outlined,
                  label: '다크 모드',
                  trailing: _buildThemeSwitch(context, ref, themeMode),
                ),
                _buildDivider(context),
                _buildMenuRow(
                  context,
                  icon: Icons.notifications_none_rounded,
                  label: '알림 설정',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () {
                    // placeholder
                  },
                ),
              ]),

              const SizedBox(height: AppSpacing.lg),

              // 계정
              _buildSectionHeader(context, '계정'),
              _buildMenuGroup(context, children: [
                _buildMenuRow(
                  context,
                  icon: Icons.person_outline_rounded,
                  label: '프로필 수정',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  onTap: () {
                    // placeholder
                  },
                ),
                _buildDivider(context),
                _buildMenuRow(
                  context,
                  icon: Icons.logout_rounded,
                  label: '로그아웃',
                  isDestructive: true,
                  onTap: () => _showLogoutDialog(context),
                ),
              ]),

              const SizedBox(height: AppSpacing.lg),

              // 정보
              _buildSectionHeader(context, '정보'),
              _buildMenuGroup(context, children: [
                _buildMenuRow(
                  context,
                  icon: Icons.info_outline_rounded,
                  label: '앱 버전',
                  trailing: Text(
                    '1.0.0',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.screenPadding + AppSpacing.sm,
        bottom: AppSpacing.sm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildMenuGroup(
    BuildContext context, {
    required List<Widget> children,
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
        child: Column(children: children),
      ),
    );
  }

  Widget _buildMenuRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
    bool isDestructive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.cardPadding,
          vertical: 14,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: isDestructive
                  ? AppColors.error
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                label,
                style: AppTypography.bodyLarge.copyWith(
                  color: isDestructive
                      ? AppColors.error
                      : AppColors.textPrimary(context),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 0.5,
      indent: AppSpacing.cardPadding + 24 + AppSpacing.md,
      color: AppColors.divider(context),
    );
  }

  Widget _buildThemeSwitch(
    BuildContext context,
    WidgetRef ref,
    ThemeMode currentMode,
  ) {
    final isDark = currentMode == ThemeMode.dark ||
        (currentMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    return Switch.adaptive(
      value: isDark,
      activeTrackColor: AppColors.primary(context),
      onChanged: (value) {
        ref.read(themeModeProvider.notifier).state =
            value ? ThemeMode.dark : ThemeMode.light;
      },
    );
  }

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
