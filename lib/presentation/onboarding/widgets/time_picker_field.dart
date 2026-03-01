import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// HH:MM:SS 시간 선택 위젯 (하단 시트 휠 피커)
/// B-4 대회기록, B-5 목표설정에서 공통 사용
class TimePickerField extends StatefulWidget {
  final int? initialSeconds;
  final ValueChanged<int?> onChanged;
  final String label;
  final bool enabled;

  const TimePickerField({
    super.key,
    this.initialSeconds,
    required this.onChanged,
    this.label = '시간',
    this.enabled = true,
  });

  @override
  State<TimePickerField> createState() => _TimePickerFieldState();
}

class _TimePickerFieldState extends State<TimePickerField> {
  int? _totalSeconds;

  @override
  void initState() {
    super.initState();
    _totalSeconds = widget.initialSeconds;
  }

  @override
  void didUpdateWidget(covariant TimePickerField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSeconds != oldWidget.initialSeconds) {
      setState(() => _totalSeconds = widget.initialSeconds);
    }
  }

  String get _displayText {
    if (_totalSeconds == null || _totalSeconds == 0) return '선택';
    final h = _totalSeconds! ~/ 3600;
    final m = (_totalSeconds! % 3600) ~/ 60;
    final s = _totalSeconds! % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _showTimePicker() {
    if (!widget.enabled) return;

    final initH = _totalSeconds != null ? _totalSeconds! ~/ 3600 : 0;
    final initM = _totalSeconds != null ? (_totalSeconds! % 3600) ~/ 60 : 0;
    final initS = _totalSeconds != null ? _totalSeconds! % 60 : 0;

    int selectedH = initH;
    int selectedM = initM;
    int selectedS = initS;

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
              // 상단 바 (취소 / 확인)
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
                        final total =
                            selectedH * 3600 + selectedM * 60 + selectedS;
                        setState(() {
                          _totalSeconds = total > 0 ? total : null;
                        });
                        widget.onChanged(total > 0 ? total : null);
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
              // 휠 피커
              Expanded(
                child: Row(
                  children: [
                    // 시간
                    Expanded(
                      child: _buildWheel(
                        ctx: ctx,
                        maxValue: 23,
                        initialValue: initH,
                        suffix: '시간',
                        onChanged: (v) => selectedH = v,
                      ),
                    ),
                    // 분
                    Expanded(
                      child: _buildWheel(
                        ctx: ctx,
                        maxValue: 59,
                        initialValue: initM,
                        suffix: '분',
                        onChanged: (v) => selectedM = v,
                      ),
                    ),
                    // 초
                    Expanded(
                      child: _buildWheel(
                        ctx: ctx,
                        maxValue: 59,
                        initialValue: initS,
                        suffix: '초',
                        onChanged: (v) => selectedS = v,
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

  Widget _buildWheel({
    required BuildContext ctx,
    required int maxValue,
    required int initialValue,
    required String suffix,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController:
          FixedExtentScrollController(initialItem: initialValue),
      itemExtent: 40,
      diameterRatio: 1.2,
      selectionOverlay: CupertinoPickerDefaultSelectionOverlay(
        background: AppColors.primary(context).withValues(alpha: 0.08),
      ),
      onSelectedItemChanged: (i) {
        HapticFeedback.selectionClick();
        onChanged(i);
      },
      children: List.generate(maxValue + 1, (i) {
        return Center(
          child: Text(
            '${i.toString().padLeft(2, '0')} $suffix',
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        GestureDetector(
          onTap: _showTimePicker,
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
                  _displayText,
                  style: AppTypography.body.copyWith(
                    color: _totalSeconds != null
                        ? AppColors.textPrimary(context)
                        : AppColors.textSecondary,
                  ),
                ),
                const Icon(
                  Icons.access_time_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
