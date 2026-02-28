import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 진행률 바
/// 주간 진행률, 거리 달성률
class ProgressBar extends StatelessWidget {
  final String leftLabel;
  final String rightLabel;
  final double progress; // 0.0 ~ 1.0

  const ProgressBar({
    super.key,
    required this.leftLabel,
    required this.rightLabel,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final clampedProgress = progress.clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              leftLabel,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              rightLabel,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 8,
            child: LinearProgressIndicator(
              value: clampedProgress,
              backgroundColor: AppColors.surfaceElevated(context),
              valueColor: AlwaysStoppedAnimation<Color>(
                AppColors.primary(context),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
