import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/distance_selector.dart';
import 'widgets/time_picker_field.dart';

/// B-5: 목표 설정 화면
class GoalSettingScreen extends ConsumerStatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  ConsumerState<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends ConsumerState<GoalSettingScreen> {
  final _raceNameController = TextEditingController();
  DateTime? _raceDate;
  double? _distanceKm;
  int? _goalTimeSeconds;
  bool _justFinish = false;
  int _trainingWeeks = 12;

  @override
  void dispose() {
    _raceNameController.dispose();
    super.dispose();
  }

  bool get _isValid => _distanceKm != null;

  void _updateTrainingWeeks() {
    if (_raceDate != null) {
      final weeks =
          _raceDate!.difference(DateTime.now()).inDays ~/ 7;
      setState(() {
        _trainingWeeks = weeks.clamp(4, 24);
      });
    }
  }

  Future<void> _onComplete() async {
    final notifier = ref.read(onboardingProvider.notifier);

    notifier.updateGoal(
      goalRaceName: _raceNameController.text.isNotEmpty
          ? _raceNameController.text
          : null,
      goalRaceDate: _raceDate,
      goalDistanceKm: _distanceKm,
      goalTimeSeconds: _justFinish ? null : _goalTimeSeconds,
      justFinishGoal: _justFinish,
      trainingWeeks: _trainingWeeks,
    );

    final success = await notifier.completeOnboarding();
    if (success && mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '5/5',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.background(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/onboarding/race-records'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                '목표를 설정해주세요',
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

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
              GestureDetector(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _raceDate ??
                        DateTime.now().add(const Duration(days: 84)),
                    firstDate: DateTime.now().add(const Duration(days: 28)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    setState(() => _raceDate = date);
                    _updateTrainingWeeks();
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface(context),
                    border: Border.all(color: AppColors.divider(context)),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.badgeRadius),
                  ),
                  child: Text(
                    _raceDate != null
                        ? '${_raceDate!.year}.${_raceDate!.month.toString().padLeft(2, '0')}.${_raceDate!.day.toString().padLeft(2, '0')}'
                        : '날짜 선택',
                    style: AppTypography.body.copyWith(
                      color: _raceDate != null
                          ? AppColors.textPrimary(context)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
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
                          ? () =>
                              setState(() => _trainingWeeks--)
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
                          ? () =>
                              setState(() => _trainingWeeks++)
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

              // 에러
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.lg),
                  child: Text(
                    state.error!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
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
              onPressed: _isValid && !state.isLoading ? _onComplete : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textDisabled(context),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '훈련표 생성하기',
                          style:
                              AppTypography.h3.copyWith(color: Colors.white),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        const Text('🚀', style: TextStyle(fontSize: 18)),
                      ],
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
