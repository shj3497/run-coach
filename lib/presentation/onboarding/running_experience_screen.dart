import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/day_selector.dart';
import 'widgets/experience_card.dart';

/// B-2: 러닝 경험 선택 화면
class RunningExperienceScreen extends ConsumerStatefulWidget {
  const RunningExperienceScreen({super.key});

  @override
  ConsumerState<RunningExperienceScreen> createState() =>
      _RunningExperienceScreenState();
}

class _RunningExperienceScreenState
    extends ConsumerState<RunningExperienceScreen> {
  String? _selectedExperience;
  int? _selectedDays;

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    _selectedExperience = state.runningExperience;
    _selectedDays = state.weeklyAvailableDays;
  }

  bool get _isValid =>
      _selectedExperience != null && _selectedDays != null;

  Future<void> _onNext() async {
    if (!_isValid) return;
    final notifier = ref.read(onboardingProvider.notifier);
    final success = await notifier.saveExperience(
      runningExperience: _selectedExperience!,
      weeklyAvailableDays: _selectedDays!,
    );
    if (success && mounted) {
      context.go('/onboarding/data-connection');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '2/5',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.background(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/onboarding/profile'),
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
                '러닝 경험을 알려주세요',
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 경험 레벨 카드
              ExperienceCard(
                icon: '🏃',
                title: '초보자',
                description: '달리기 시작한 지 6개월 미만',
                isSelected: _selectedExperience == 'beginner',
                onTap: () =>
                    setState(() => _selectedExperience = 'beginner'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExperienceCard(
                icon: '🏃‍♂️',
                title: '중급자',
                description: '정기적으로 달리기 / 6개월 ~ 2년',
                isSelected: _selectedExperience == 'intermediate',
                onTap: () =>
                    setState(() => _selectedExperience = 'intermediate'),
              ),
              const SizedBox(height: AppSpacing.sm),
              ExperienceCard(
                icon: '🏅',
                title: '고급자',
                description: '대회 참가 경험 / 2년 이상',
                isSelected: _selectedExperience == 'advanced',
                onTap: () =>
                    setState(() => _selectedExperience = 'advanced'),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 주간 훈련 가능일수
              Text(
                '주간 훈련 가능일수',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              DaySelector(
                selectedDays: _selectedDays,
                onChanged: (days) => setState(() => _selectedDays = days),
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
              onPressed: _isValid && !state.isLoading ? _onNext : null,
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
                  : Text(
                      '다음',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
