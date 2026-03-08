import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/training_session.dart';
import '../../domain/usecases/calculate_weekly_stats.dart';
import '../common/widgets/coaching_message_card.dart';
import '../providers/coaching_providers.dart';
import '../providers/data_providers.dart';

/// D-3 주간 리뷰 화면
///
/// 주차별 달성도 분석 + AI 코칭 리뷰를 표시합니다.
class WeeklyReviewScreen extends ConsumerWidget {
  final String weekId;

  const WeeklyReviewScreen({super.key, required this.weekId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(dbWeekSessionsProvider(weekId));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: Text(
          '주간 리뷰',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: sessionsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (_, __) => Center(
          child: Text(
            '데이터를 불러올 수 없습니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        data: (sessions) => _buildContent(context, ref, sessions),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    List<TrainingSession> sessions,
  ) {
    final stats = const CalculateWeeklyStats().execute(sessions: sessions);
    final reviewAsync = ref.watch(weeklyReviewProvider(weekId));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // 종합 달성률 원형 프로그레스
          _buildOverallProgress(context, stats),

          const SizedBox(height: AppSpacing.xl),

          // 세션 완료/거리 진행률
          _buildProgressStats(context, stats),

          const SizedBox(height: AppSpacing.xl),

          // 세션 리스트
          Text(
            '세션 내역',
            style: AppTypography.h2.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildSessionList(context, sessions),

          const SizedBox(height: AppSpacing.xl),

          // AI 코칭 리뷰
          Text(
            'AI 코칭 리뷰',
            style: AppTypography.h2.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          reviewAsync.when(
            loading: () => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Text(
                '리뷰를 불러오는 중...',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            error: (_, __) => _buildNoReview(context),
            data: (content) {
              if (content == null) return _buildNoReview(context);
              return CoachingMessageCard(
                message: content,
                timestamp: '',
              );
            },
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// 종합 달성률 원형 프로그레스
  Widget _buildOverallProgress(BuildContext context, WeeklyStats stats) {
    final overallRate = stats.overallCompletionRate.clamp(0.0, 100.0);
    final progressColor = _getProgressColor(overallRate);
    final progressValue = overallRate / 100.0;

    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PieChart(
              PieChartData(
                startDegreeOffset: -90,
                sectionsSpace: 0,
                centerSpaceRadius: 62,
                sections: [
                  PieChartSectionData(
                    value: progressValue,
                    color: progressColor,
                    radius: 12,
                    showTitle: false,
                  ),
                  if (progressValue < 1.0)
                    PieChartSectionData(
                      value: 1.0 - progressValue,
                      color: AppColors.divider(context),
                      radius: 12,
                      showTitle: false,
                    ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${overallRate.toStringAsFixed(0)}%',
                  style: AppTypography.h1.copyWith(
                    color: AppColors.textPrimary(context),
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '종합 달성률',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 세션/거리 진행률 카드
  Widget _buildProgressStats(BuildContext context, WeeklyStats stats) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.check_circle_outline_rounded,
            label: '세션 완료',
            value: '${stats.completedSessions}/${stats.totalSessions}',
            subValue: '${stats.sessionCompletionRate.toStringAsFixed(0)}%',
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.straighten_rounded,
            label: '거리 달성',
            value:
                '${stats.completedDistanceKm.toStringAsFixed(1)}/${stats.targetDistanceKm.toStringAsFixed(1)}km',
            subValue: '${stats.distanceCompletionRate.toStringAsFixed(0)}%',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary(context)),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            subValue,
            style: AppTypography.h2.copyWith(
              color: AppColors.primary(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 세션 리스트
  Widget _buildSessionList(
    BuildContext context,
    List<TrainingSession> sessions,
  ) {
    final trainingSessions =
        sessions.where((s) => s.sessionType != 'rest').toList();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: trainingSessions.asMap().entries.map((entry) {
          final index = entry.key;
          final session = entry.value;
          final zone = TrainingZones.fromType(
            trainingZoneTypeFromDbString(session.sessionType),
          );

          return Column(
            children: [
              if (index > 0)
                Divider(
                  color: AppColors.divider(context),
                  height: AppSpacing.lg,
                ),
              GestureDetector(
                onTap: () {
                  context.push('/plan/session/${session.id}');
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  children: [
                    // 컬러 인디케이터
                    Container(
                      width: 4,
                      height: 36,
                      decoration: BoxDecoration(
                        color: zone.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // 세션 정보
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.title,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              zone.label,
                              if (session.targetDistanceKm != null)
                                '${session.targetDistanceKm!.toStringAsFixed(0)}km',
                            ].join(' · '),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 상태 배지
                    _buildStatusBadge(context, session.status),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'completed':
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = '완료';
      case 'skipped':
        bgColor = AppColors.error.withValues(alpha: 0.15);
        textColor = AppColors.error;
        label = '건너뜀';
      case 'partial':
        bgColor = AppColors.warning.withValues(alpha: 0.15);
        textColor = AppColors.warning;
        label = '부분';
      default:
        bgColor = AppColors.textSecondary.withValues(alpha: 0.1);
        textColor = AppColors.textSecondary;
        label = '대기';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildNoReview(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          Icon(
            Icons.smart_toy_outlined,
            size: 32,
            color: AppColors.textSecondary.withValues(alpha: 0.4),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '아직 AI 리뷰가 생성되지 않았습니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '주차가 완료되면 자동으로 리뷰가 생성됩니다',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Color _getProgressColor(double rate) {
    if (rate >= 80) return AppColors.success;
    if (rate >= 50) return AppColors.warning;
    return AppColors.error;
  }
}
