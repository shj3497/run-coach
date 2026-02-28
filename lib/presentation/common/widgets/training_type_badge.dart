import 'package:flutter/material.dart';
import '../../../core/constants/training_zones.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 훈련 유형 배지
/// 예: "이지런" → 초록 배경(20%), 초록 텍스트
class TrainingTypeBadge extends StatelessWidget {
  final TrainingZone zone;

  const TrainingTypeBadge({super.key, required this.zone});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: zone.badgeBackground,
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(
        zone.shortLabel,
        style: AppTypography.bodySmall.copyWith(
          color: zone.color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
