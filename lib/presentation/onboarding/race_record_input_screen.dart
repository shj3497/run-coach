import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/race_record_form.dart';
import 'widgets/race_record_tile.dart';

/// B-4: 대회 기록 입력 화면
class RaceRecordInputScreen extends ConsumerWidget {
  const RaceRecordInputScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);
    final notifier = ref.read(onboardingProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '4/5',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.background(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/onboarding/data-connection'),
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
                '과거 대회 기록이 있나요?',
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'VDOT 분석에 활용됩니다',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 기록 입력 폼
              RaceRecordForm(
                onSubmit: ({
                  required String raceName,
                  required DateTime raceDate,
                  required double distanceKm,
                  required int finishTimeSeconds,
                }) async {
                  await notifier.addRaceRecord(
                    raceName: raceName,
                    raceDate: raceDate,
                    distanceKm: distanceKm,
                    finishTimeSeconds: finishTimeSeconds,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // 추가된 기록 리스트
              if (state.raceRecords.isNotEmpty) ...[
                Text(
                  '추가된 기록',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...state.raceRecords.map(
                  (record) => Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: RaceRecordTile(
                      record: record,
                      onDelete: () =>
                          notifier.removeRaceRecord(record.id),
                    ),
                  ),
                ),
              ],

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
          child: Row(
            children: [
              // 건너뛰기
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: TextButton(
                    onPressed: () => context.go('/onboarding/goal'),
                    child: Text(
                      '건너뛰기',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 다음
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => context.go('/onboarding/goal'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                    ),
                    child: Text(
                      '다음',
                      style:
                          AppTypography.h3.copyWith(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
