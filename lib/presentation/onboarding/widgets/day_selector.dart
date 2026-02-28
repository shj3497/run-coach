import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// B-2 주간 훈련 가능일수 선택 위젯 (1~7일)
class DaySelector extends StatelessWidget {
  final int? selectedDays;
  final ValueChanged<int> onChanged;
  final int maxDays;

  const DaySelector({
    super.key,
    this.selectedDays,
    required this.onChanged,
    this.maxDays = 7,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxDays, (index) {
        final day = index + 1;
        final isSelected = day == selectedDays;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: GestureDetector(
            onTap: () => onChanged(day),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary(context)
                    : AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary(context)
                      : AppColors.divider(context),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '$day',
                style: AppTypography.h3.copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textPrimary(context),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}
