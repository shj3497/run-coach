import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 하단 시트 날짜 선택 위젯 (Cupertino 휠 피커)
/// B-4 대회기록, B-5 목표설정, D-5 플랜생성에서 공통 사용
class DatePickerField extends StatefulWidget {
  final DateTime? initialDate;
  final ValueChanged<DateTime?> onChanged;
  final String label;
  final String placeholder;

  /// 선택 가능한 최소 날짜
  final DateTime? firstDate;

  /// 선택 가능한 최대 날짜
  final DateTime? lastDate;

  const DatePickerField({
    super.key,
    this.initialDate,
    required this.onChanged,
    this.label = '날짜',
    this.placeholder = '선택',
    this.firstDate,
    this.lastDate,
  });

  @override
  State<DatePickerField> createState() => _DatePickerFieldState();
}

class _DatePickerFieldState extends State<DatePickerField> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate;
  }

  @override
  void didUpdateWidget(covariant DatePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialDate != oldWidget.initialDate) {
      setState(() => _selectedDate = widget.initialDate);
    }
  }

  String get _displayText {
    if (_selectedDate == null) return widget.placeholder;
    return '${_selectedDate!.year}.${_selectedDate!.month.toString().padLeft(2, '0')}.${_selectedDate!.day.toString().padLeft(2, '0')}';
  }

  void _showDatePicker() {
    final now = DateTime.now();
    final first = widget.firstDate ?? DateTime(2000);
    final last = widget.lastDate ?? DateTime(now.year + 2);

    final initDate = _selectedDate ?? now;
    // 초기값이 범위 밖이면 clamp
    final clamped = initDate.isBefore(first)
        ? first
        : initDate.isAfter(last)
            ? last
            : initDate;

    final years = List.generate(
      last.year - first.year + 1,
      (i) => first.year + i,
    );

    int selectedYear = clamped.year;
    int selectedMonth = clamped.month;
    int selectedDay = clamped.day;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        '취소',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      widget.label,
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final maxDay =
                            DateTime(selectedYear, selectedMonth + 1, 0).day;
                        final safeDay =
                            selectedDay > maxDay ? maxDay : selectedDay;
                        var date =
                            DateTime(selectedYear, selectedMonth, safeDay);
                        // 범위 내로 clamp
                        if (date.isBefore(first)) date = first;
                        if (date.isAfter(last)) date = last;
                        setState(() => _selectedDate = date);
                        widget.onChanged(date);
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        '확인',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider(context)),
              Expanded(
                child: Row(
                  children: [
                    // 년
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: years.indexOf(selectedYear),
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                          background:
                              AppColors.primary(context).withValues(alpha: 0.08),
                        ),
                        onSelectedItemChanged: (i) {
                            HapticFeedback.selectionClick();
                            selectedYear = years[i];
                        },
                        children: years.map((y) {
                          return Center(
                            child: Text(
                              '$y년',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // 월
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedMonth - 1,
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                          background:
                              AppColors.primary(context).withValues(alpha: 0.08),
                        ),
                        onSelectedItemChanged: (i) {
                            HapticFeedback.selectionClick();
                            selectedMonth = i + 1;
                        },
                        children: List.generate(12, (i) {
                          return Center(
                            child: Text(
                              '${i + 1}월',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 일
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: selectedDay - 1,
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                          background:
                              AppColors.primary(context).withValues(alpha: 0.08),
                        ),
                        onSelectedItemChanged: (i) {
                            HapticFeedback.selectionClick();
                            selectedDay = i + 1;
                        },
                        children: List.generate(31, (i) {
                          return Center(
                            child: Text(
                              '${i + 1}일',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _showDatePicker,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          border: Border.all(color: AppColors.divider(context)),
          borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        ),
        child: Text(
          _displayText,
          style: AppTypography.body.copyWith(
            color: _selectedDate != null
                ? AppColors.textPrimary(context)
                : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
