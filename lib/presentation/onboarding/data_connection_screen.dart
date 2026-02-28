import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/connection_card.dart';

/// B-3: 데이터 연동 화면
class DataConnectionScreen extends ConsumerWidget {
  const DataConnectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '3/5',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.background(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/onboarding/experience'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                '운동 데이터를\n연동해주세요',
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '데이터 연동은 추후 업데이트될 예정입니다',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Apple Health
              ConnectionCard(
                icon: Icons.favorite,
                iconColor: AppColors.error,
                title: 'Apple Health',
                subtitle: '워크아웃, 심박수, 거리 데이터',
                isRequired: true,
                isConnected: state.healthKitConnected,
                onConnect: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('HealthKit 연동은 추후 업데이트 예정입니다'),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // Strava
              ConnectionCard(
                icon: Icons.pedal_bike,
                iconColor: const Color(0xFFFC4C02),
                title: 'Strava',
                subtitle: '선택 (더 풍부한 데이터 활용 가능)',
                isConnected: state.stravaConnected,
                onConnect: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Strava 연동은 추후 업데이트 예정입니다'),
                    ),
                  );
                },
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
              onPressed: () => context.go('/onboarding/race-records'),
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
                style: AppTypography.h3.copyWith(color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
