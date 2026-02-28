import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../onboarding/widgets/date_picker_field.dart';
import '../onboarding/widgets/distance_selector.dart';
import '../onboarding/widgets/time_picker_field.dart';

/// D-5 플랜 생성 화면
/// B-5 목표 설정과 동일한 UI 컴포넌트 사용
class PlanCreateScreen extends ConsumerStatefulWidget {
  const PlanCreateScreen({super.key});

  @override
  ConsumerState<PlanCreateScreen> createState() => _PlanCreateScreenState();
}

class _PlanCreateScreenState extends ConsumerState<PlanCreateScreen> {
  final _raceNameController = TextEditingController();
  DateTime? _raceDate;
  double? _distanceKm;
  int? _goalTimeSeconds;
  bool _justFinish = false;
  int _trainingWeeks = 12;
  bool _isLoading = false;

  @override
  void dispose() {
    _raceNameController.dispose();
    super.dispose();
  }

  bool get _isValid => _distanceKm != null;

  void _updateTrainingWeeks() {
    if (_raceDate != null) {
      final weeks = _raceDate!.difference(DateTime.now()).inDays ~/ 7;
      setState(() {
        _trainingWeeks = weeks.clamp(4, 24);
      });
    }
  }

  Future<void> _onCreate() async {
    if (!_isValid) return;

    setState(() => _isLoading = true);

    // Phase 3: LLM 훈련표 생성을 시뮬레이션
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '훈련표가 생성되었습니다!',
            style: AppTypography.body.copyWith(color: Colors.white),
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
          ),
        ),
      );

      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: Text(
          '새 플랜 만들기',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // 대회명 (선택)
              _buildLabel(context, '대회명 (선택)'),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _raceNameController,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary(context),
                ),
                decoration: _inputDecoration(context, '예: 2026 서울마라톤'),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 대회 날짜 (선택)
              _buildLabel(context, '대회 날짜 (선택)'),
              const SizedBox(height: AppSpacing.sm),
              DatePickerField(
                label: '대회 날짜',
                placeholder: '날짜 선택',
                initialDate: _raceDate,
                firstDate: DateTime.now().add(const Duration(days: 28)),
                lastDate: DateTime.now().add(const Duration(days: 365)),
                onChanged: (date) {
                  setState(() => _raceDate = date);
                  _updateTrainingWeeks();
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // 목표 거리 (필수)
              _buildLabel(context, '목표 거리', required: true),
              const SizedBox(height: AppSpacing.sm),
              DistanceSelector(
                selectedDistanceKm: _distanceKm,
                onChanged: (km) => setState(() => _distanceKm = km),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 목표 시간
              _buildLabel(context, '목표 시간'),
              const SizedBox(height: AppSpacing.sm),
              TimePickerField(
                label: '',
                initialSeconds: _goalTimeSeconds,
                enabled: !_justFinish,
                onChanged: (seconds) =>
                    setState(() => _goalTimeSeconds = seconds),
              ),
              const SizedBox(height: AppSpacing.sm),

              // 완주가 목표 체크박스
              GestureDetector(
                onTap: () => setState(() {
                  _justFinish = !_justFinish;
                  if (_justFinish) _goalTimeSeconds = null;
                }),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: _justFinish
                            ? AppColors.primary(context)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _justFinish
                              ? AppColors.primary(context)
                              : AppColors.divider(context),
                          width: 2,
                        ),
                      ),
                      child: _justFinish
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '완주가 목표입니다',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 훈련 기간
              _buildLabel(context, '훈련 기간'),
              const SizedBox(height: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius:
                      BorderRadius.circular(AppSpacing.cardRadius),
                  border: Border.all(color: AppColors.divider(context)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      onPressed: _trainingWeeks > 4
                          ? () => setState(() => _trainingWeeks--)
                          : null,
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: _trainingWeeks > 4
                            ? AppColors.primary(context)
                            : AppColors.textDisabled(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Text(
                      '$_trainingWeeks주',
                      style: AppTypography.h1.copyWith(
                        color: AppColors.primary(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    IconButton(
                      onPressed: _trainingWeeks < 24
                          ? () => setState(() => _trainingWeeks++)
                          : null,
                      icon: Icon(
                        Icons.add_circle_outline,
                        color: _trainingWeeks < 24
                            ? AppColors.primary(context)
                            : AppColors.textDisabled(context),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isValid && !_isLoading ? _onCreate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textDisabled(context),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '훈련표 생성하기',
                      style: AppTypography.h3.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(BuildContext context, String label,
      {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppTypography.body.copyWith(color: AppColors.error),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.surface(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        borderSide: BorderSide(color: AppColors.divider(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        borderSide: BorderSide(color: AppColors.divider(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        borderSide: BorderSide(
          color: AppColors.primary(context),
          width: 2,
        ),
      ),
    );
  }
}
