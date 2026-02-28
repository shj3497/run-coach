import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 코칭 메시지 카드
/// LLM 코칭 메시지 표시
class CoachingMessageCard extends StatelessWidget {
  final String message;
  final String? timestamp;
  final VoidCallback? onTap;

  const CoachingMessageCard({
    super.key,
    required this.message,
    this.timestamp,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 좌측 Primary 액센트 바
            Container(
              width: 4,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary(context),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // AI 아이콘
            Icon(
              Icons.smart_toy_outlined,
              size: 20,
              color: AppColors.primary(context),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 메시지
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timestamp != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      timestamp!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
