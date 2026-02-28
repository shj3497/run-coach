import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../common/widgets/coaching_message_card.dart';
import '../common/widgets/progress_bar.dart';
import '../common/widgets/training_session_card.dart';
import '../common/widgets/weather_card.dart';
import 'providers/home_provider.dart';

/// C-1 홈 화면 (오늘의 훈련)
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final homeAsync = ref.watch(homeStateProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: homeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Text(
            '오류가 발생했습니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        data: (state) => state.hasPlan
            ? _buildActiveContent(context, state)
            : _buildEmptyContent(context),
      ),
    );
  }

  /// 활성 플랜이 있을 때의 홈 화면
  Widget _buildActiveContent(BuildContext context, HomeState state) {
    final greeting = _getGreeting();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenPadding,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.xl),

            // 인사 메시지
            Text(
              '$greeting, ${state.nickname}!',
              style: AppTypography.h1.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // 날씨 카드 (Phase 5 전까지 mock)
            const WeatherCard(
              weatherIcon: Icons.wb_sunny_rounded,
              temperature: '12\u00B0C',
              condition: '맑음',
              message: '오늘 날씨 좋아요! 계획대로 뛰세요',
            ),
            const SizedBox(height: AppSpacing.lg),

            // 오늘의 훈련 섹션
            Text(
              '오늘의 훈련',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (state.todaySession != null)
              TrainingSessionCard(
                zone: TrainingZones.fromType(state.todaySession!.zoneType),
                title: state.todaySession!.title,
                targetPace: state.todaySession!.targetPace,
                estimatedTime: state.todaySession!.estimatedTime,
                status: SessionStatus.pending,
                onTap: () {
                  context.push('/plan/session/${state.todaySession!.id}');
                },
              )
            else
              _buildNoSessionCard(context),

            const SizedBox(height: AppSpacing.xl),

            // 이번 주 진행률 섹션
            Text(
              '이번 주 진행률',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (state.weeklyProgress != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.cardPadding),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                ),
                child: Column(
                  children: [
                    ProgressBar(
                      leftLabel:
                          '${state.weeklyProgress!.completedSessions}/${state.weeklyProgress!.totalSessions} 세션',
                      rightLabel:
                          '${(state.weeklyProgress!.sessionProgress * 100).toInt()}%',
                      progress: state.weeklyProgress!.sessionProgress,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    ProgressBar(
                      leftLabel:
                          '${state.weeklyProgress!.completedKm.toStringAsFixed(0)}km / ${state.weeklyProgress!.totalKm.toStringAsFixed(0)}km',
                      rightLabel:
                          '${(state.weeklyProgress!.distanceProgress * 100).toInt()}%',
                      progress: state.weeklyProgress!.distanceProgress,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // 코칭 메시지 섹션
            Text(
              '코칭 메시지',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            if (state.latestCoaching != null)
              CoachingMessageCard(
                message: state.latestCoaching!.message,
                timestamp: _formatTimestamp(state.latestCoaching!.timestamp),
                onTap: () {
                  // TODO: D-3 주간 리뷰로 이동
                },
              )
            else
              _buildNoCoachingCard(context),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  /// 활성 플랜이 없을 때 빈 상태
  Widget _buildEmptyContent(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.directions_run_rounded,
                size: 80,
                color: AppColors.primary(context).withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '훈련 플랜을 생성해보세요',
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI가 맞춤 훈련표를 만들어 드립니다',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => context.push('/plan/create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary(context),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSpacing.buttonRadius),
                    ),
                  ),
                  child: Text(
                    '새 플랜 만들기',
                    style: AppTypography.h3.copyWith(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSessionCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 32,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '오늘은 휴식일입니다',
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCoachingCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 24,
            color: AppColors.textSecondary.withOpacity(0.5),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '아직 코칭 메시지가 없습니다',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 6) return '좋은 새벽';
    if (hour < 12) return '좋은 아침';
    if (hour < 18) return '좋은 오후';
    return '좋은 저녁';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    if (diff.inDays < 7) return '${diff.inDays}일 전';
    return '${timestamp.month}/${timestamp.day}';
  }
}
