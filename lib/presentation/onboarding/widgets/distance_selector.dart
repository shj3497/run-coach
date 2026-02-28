import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/vdot_calculator.dart';

/// 거리 선택 위젯 (5K / 10K / 하프 / 풀)
/// B-4 대회기록, B-5 목표설정에서 공통 사용
class DistanceSelector extends StatelessWidget {
  final double? selectedDistanceKm;
  final ValueChanged<double> onChanged;

  const DistanceSelector({
    super.key,
    this.selectedDistanceKm,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: VdotCalculator.standardDistances.entries.map((entry) {
        final label = entry.key;
        final km = entry.value;
        final isSelected = selectedDistanceKm == km;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => onChanged(km),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary(context)
                      : AppColors.surface(context),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.badgeRadius),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary(context)
                        : AppColors.divider(context),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: AppTypography.h3.copyWith(
                    color: isSelected
                        ? Colors.white
                        : AppColors.textPrimary(context),
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
