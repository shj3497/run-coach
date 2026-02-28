import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 소셜 로그인 타입
enum SocialLoginType {
  apple,
  google,
  kakao,
}

/// 소셜 로그인 버튼
class SocialLoginButton extends StatelessWidget {
  final SocialLoginType type;
  final VoidCallback? onPressed;

  const SocialLoginButton({
    super.key,
    required this.type,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;

    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _backgroundColor(isLight),
          foregroundColor: _foregroundColor(isLight),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            side: type == SocialLoginType.google
                ? BorderSide(color: Colors.grey.shade300)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(isLight),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _label,
              style: AppTypography.h3.copyWith(
                color: _foregroundColor(isLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _label {
    switch (type) {
      case SocialLoginType.apple:
        return 'Apple로 시작하기';
      case SocialLoginType.google:
        return 'Google로 시작하기';
      case SocialLoginType.kakao:
        return '카카오로 시작하기';
    }
  }

  Color _backgroundColor(bool isLight) {
    switch (type) {
      case SocialLoginType.apple:
        return isLight ? AppColors.appleLight : AppColors.appleDark;
      case SocialLoginType.google:
        return isLight ? AppColors.googleLight : AppColors.googleDark;
      case SocialLoginType.kakao:
        return AppColors.kakao;
    }
  }

  Color _foregroundColor(bool isLight) {
    switch (type) {
      case SocialLoginType.apple:
        return isLight ? Colors.white : Colors.black;
      case SocialLoginType.google:
        return isLight ? Colors.black87 : Colors.white;
      case SocialLoginType.kakao:
        return Colors.black87;
    }
  }

  Widget _buildIcon(bool isLight) {
    switch (type) {
      case SocialLoginType.apple:
        return Icon(
          Icons.apple,
          size: 24,
          color: isLight ? Colors.white : Colors.black,
        );
      case SocialLoginType.google:
        return Icon(
          Icons.g_mobiledata,
          size: 24,
          color: isLight ? Colors.black87 : Colors.white,
        );
      case SocialLoginType.kakao:
        return const Icon(
          Icons.chat_bubble,
          size: 20,
          color: Colors.black87,
        );
    }
  }
}
