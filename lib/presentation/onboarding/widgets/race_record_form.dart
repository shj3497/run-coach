import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/vdot_calculator.dart';
import 'distance_selector.dart';
import 'time_picker_field.dart';

/// B-4 대회 기록 입력 폼
class RaceRecordForm extends StatefulWidget {
  final Future<void> Function({
    required String raceName,
    required DateTime raceDate,
    required double distanceKm,
    required int finishTimeSeconds,
  }) onSubmit;

  const RaceRecordForm({super.key, required this.onSubmit});

  @override
  State<RaceRecordForm> createState() => _RaceRecordFormState();
}

class _RaceRecordFormState extends State<RaceRecordForm> {
  final _nameController = TextEditingController();
  DateTime? _raceDate;
  double? _distanceKm;
  int? _finishTimeSeconds;
  double? _previewVdot;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _updateVdotPreview() {
    if (_distanceKm != null && _finishTimeSeconds != null) {
      final vdot = VdotCalculator.calculate(
        distanceKm: _distanceKm!,
        finishTimeSeconds: _finishTimeSeconds!,
      );
      setState(() => _previewVdot = vdot);
    } else {
      setState(() => _previewVdot = null);
    }
  }

  bool get _isValid =>
      _nameController.text.isNotEmpty &&
      _raceDate != null &&
      _distanceKm != null &&
      _finishTimeSeconds != null &&
      _finishTimeSeconds! > 0;

  Future<void> _submit() async {
    if (!_isValid || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    await widget.onSubmit(
      raceName: _nameController.text,
      raceDate: _raceDate!,
      distanceKm: _distanceKm!,
      finishTimeSeconds: _finishTimeSeconds!,
    );
    setState(() {
      _nameController.clear();
      _raceDate = null;
      _distanceKm = null;
      _finishTimeSeconds = null;
      _previewVdot = null;
      _isSubmitting = false;
    });
  }

  void _showDatePicker(BuildContext context) {
    final now = DateTime.now();
    final initYear = _raceDate?.year ?? now.year;
    final initMonth = _raceDate?.month ?? now.month;
    final initDay = _raceDate?.day ?? now.day;

    int selectedYear = initYear;
    int selectedMonth = initMonth;
    int selectedDay = initDay;

    // 년도 범위: 2000 ~ 현재
    const startYear = 2000;
    final years = List.generate(now.year - startYear + 1, (i) => startYear + i);

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
                      '대회 날짜',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // 선택한 월의 최대 일수 보정
                        final maxDay = DateTime(selectedYear, selectedMonth + 1, 0).day;
                        final safeDay = selectedDay > maxDay ? maxDay : selectedDay;
                        final date = DateTime(selectedYear, selectedMonth, safeDay);
                        // 미래 날짜 방지
                        final finalDate = date.isAfter(now) ? now : date;
                        setState(() => _raceDate = finalDate);
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
                          initialItem: years.indexOf(initYear),
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                          background: AppColors.primary(context).withOpacity(0.08),
                        ),
                        onSelectedItemChanged: (i) => selectedYear = years[i],
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
                          initialItem: initMonth - 1,
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                          background: AppColors.primary(context).withOpacity(0.08),
                        ),
                        onSelectedItemChanged: (i) => selectedMonth = i + 1,
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
                          initialItem: initDay - 1,
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
                          background: AppColors.primary(context).withOpacity(0.08),
                        ),
                        onSelectedItemChanged: (i) => selectedDay = i + 1,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.divider(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 대회명
          TextField(
            controller: _nameController,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary(context),
            ),
            decoration: InputDecoration(
              labelText: '대회명',
              labelStyle: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 대회 날짜
          Text(
            '대회 날짜',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: () => _showDatePicker(context),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _raceDate != null
                        ? '${_raceDate!.year}년 ${_raceDate!.month.toString().padLeft(2, '0')}월 ${_raceDate!.day.toString().padLeft(2, '0')}일'
                        : '선택',
                    style: AppTypography.body.copyWith(
                      color: _raceDate != null
                          ? AppColors.textPrimary(context)
                          : AppColors.textSecondary,
                    ),
                  ),
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 거리
          Text(
            '거리',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          DistanceSelector(
            selectedDistanceKm: _distanceKm,
            onChanged: (km) {
              setState(() => _distanceKm = km);
              _updateVdotPreview();
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // 완주 시간
          TimePickerField(
            label: '완주 시간',
            initialSeconds: _finishTimeSeconds,
            onChanged: (seconds) {
              setState(() => _finishTimeSeconds = seconds);
              _updateVdotPreview();
            },
          ),
          const SizedBox(height: AppSpacing.md),

          // VDOT 미리보기
          if (_previewVdot != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primaryBackground(context),
                borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'VDOT: ',
                    style: AppTypography.body.copyWith(
                      color: AppColors.primary(context),
                    ),
                  ),
                  Text(
                    _previewVdot!.toStringAsFixed(1),
                    style: AppTypography.h2.copyWith(
                      color: AppColors.primary(context),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),

          // 추가 버튼
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _isValid && !_isSubmitting ? _submit : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.textDisabled(context),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '추가',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
