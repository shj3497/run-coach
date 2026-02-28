import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../data/models/race_record.dart';

/// B-4 추가된 대회 기록 타일
class RaceRecordTile extends StatelessWidget {
  final RaceRecord record;
  final VoidCallback? onDelete;

  const RaceRecordTile({
    super.key,
    required this.record,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.raceName,
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${record.distanceKm}km / ${TimeFormatter.toHHMMSS(record.finishTimeSeconds)}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                if (record.vdotScore != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'VDOT: ${record.vdotScore!.toStringAsFixed(1)}',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.primary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              icon: const Icon(
                Icons.close,
                size: 20,
                color: AppColors.textSecondary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(
                minWidth: 32,
                minHeight: 32,
              ),
            ),
        ],
      ),
    );
  }
}
