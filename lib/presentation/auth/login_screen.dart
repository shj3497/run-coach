import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../common/widgets/social_login_button.dart';
import 'providers/auth_providers.dart';

/// A-2: 로그인 화면
/// 소셜 로그인 3종 (UI만) + 개발자 모드 임시 로그인
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  Future<void> _signInAnonymously() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInAnonymously();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로그인에 실패했습니다: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('소셜 로그인은 추후 업데이트 예정입니다'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            children: [
              const Spacer(flex: 2),
              // 로고 + 타이틀
              Icon(
                Icons.directions_run_rounded,
                size: 80,
                color: AppColors.primary(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '런닝 코치',
                style: AppTypography.display.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI 런닝 코치',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(flex: 2),
              // 소셜 로그인 버튼
              SocialLoginButton(
                type: SocialLoginType.apple,
                onPressed: _showComingSoon,
              ),
              const SizedBox(height: AppSpacing.sm),
              SocialLoginButton(
                type: SocialLoginType.google,
                onPressed: _showComingSoon,
              ),
              const SizedBox(height: AppSpacing.sm),
              SocialLoginButton(
                type: SocialLoginType.kakao,
                onPressed: _showComingSoon,
              ),
              const SizedBox(height: AppSpacing.xl),
              // 개발자 모드 (임시)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _isLoading ? null : _signInAnonymously,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: AppColors.primary(context),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary(context),
                          ),
                        )
                      : Text(
                          '개발자 모드로 시작',
                          style: AppTypography.h3.copyWith(
                            color: AppColors.primary(context),
                          ),
                        ),
                ),
              ),
              const Spacer(),
              // 약관
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      '이용약관',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '|',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textDisabled(context),
                    ),
                  ),
                  TextButton(
                    onPressed: () {},
                    child: Text(
                      '개인정보처리방침',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }
}
