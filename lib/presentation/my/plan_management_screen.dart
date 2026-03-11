import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/training_plan.dart';
import '../providers/data_providers.dart';

/// D-6 내 플랜 관리 화면 — 전체 플랜 목록 (상태별 표시)
class PlanManagementScreen extends ConsumerWidget {
  const PlanManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(userPlansProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '내 플랜 관리',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
      ),
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(
          child: Text(
            '플랜을 불러오는데 실패했습니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        data: (plans) {
          if (plans.isEmpty) {
            return _buildEmptyState(context);
          }
          return _buildPlanList(context, plans);
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month_rounded,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.3),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              '생성된 플랜이 없습니다',
              style: AppTypography.h3.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanList(BuildContext context, List<TrainingPlan> plans) {
    // 상태별 그룹핑: 활성 → 대기 → 완료 → 취소
    final active = plans.where((p) => p.status == 'active').toList();
    final upcoming = plans.where((p) => p.status == 'upcoming').toList();
    final completed = plans.where((p) => p.status == 'completed').toList();
    final cancelled = plans.where((p) => p.status == 'cancelled').toList();

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.lg,
      ),
      children: [
        if (active.isNotEmpty)
          _buildSection(context, '활성', active),
        if (upcoming.isNotEmpty)
          _buildSection(context, '대기', upcoming),
        if (completed.isNotEmpty)
          _buildSection(context, '완료', completed),
        if (cancelled.isNotEmpty)
          _buildSection(context, '취소', cancelled),
        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<TrainingPlan> plans,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$title (${plans.length})',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...plans.map(
          (plan) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _buildPlanCard(context, plan),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildPlanCard(BuildContext context, TrainingPlan plan) {
    final statusInfo = _getStatusInfo(plan.status);

    return GestureDetector(
      onTap: () => context.push('/plan/detail/${plan.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 이름 + 상태 배지
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan.planName,
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusInfo.color.withValues(alpha: 0.15),
                    borderRadius:
                        BorderRadius.circular(AppSpacing.badgeRadius),
                  ),
                  child: Text(
                    statusInfo.label,
                    style: AppTypography.caption.copyWith(
                      color: statusInfo.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 거리 · 기간 · 주차
            Text(
              _buildSubtitle(plan),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),

            // 목표 시간
            if (plan.goalTimeSeconds != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                '목표 ${TimeFormatter.toHHMMSS(plan.goalTimeSeconds!)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildSubtitle(TrainingPlan plan) {
    final parts = <String>[];
    parts.add(_formatDistance(plan.goalDistanceKm));
    parts.add(
      '${_formatDate(plan.startDate)} ~ ${_formatDate(plan.endDate)}',
    );
    parts.add('${plan.totalWeeks}주');
    return parts.join(' · ');
  }

  String _formatDistance(double km) {
    if (km == 5.0) return '5K';
    if (km == 10.0) return '10K';
    if (km == 21.0975) return '하프';
    if (km == 42.195) return '풀 마라톤';
    return '${km.toStringAsFixed(1)}km';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }

  ({Color color, String label}) _getStatusInfo(String status) {
    switch (status) {
      case 'active':
        return (color: AppColors.success, label: '활성');
      case 'completed':
        return (color: AppColors.textSecondary, label: '완료');
      case 'cancelled':
        return (color: AppColors.warning, label: '취소');
      default:
        return (color: AppColors.primaryLight, label: '대기');
    }
  }
}
