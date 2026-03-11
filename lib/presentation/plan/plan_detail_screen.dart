import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/time_formatter.dart';
import '../../core/utils/vdot_calculator.dart';
import '../../data/models/training_plan.dart';
import '../providers/data_providers.dart';
import 'providers/plan_provider.dart';

/// D-6 플랜 상세/관리 화면
class PlanDetailScreen extends ConsumerWidget {
  final String planId;

  const PlanDetailScreen({super.key, required this.planId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 활성 플랜이면 planProvider에서, 아니면 planByIdProvider로 조회
    final planState = ref.watch(planProvider);
    final activePlan = planState.activePlan;
    final bool isActivePlan = activePlan != null && activePlan.id == planId;

    if (isActivePlan) {
      return _buildContent(context, ref, activePlan);
    }

    // 비활성 플랜 (취소/완료/대기) — DB에서 직접 조회
    final planAsync = ref.watch(planByIdProvider(planId));

    return planAsync.when(
      loading: () => Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(backgroundColor: AppColors.background(context)),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(backgroundColor: AppColors.background(context)),
        body: Center(
          child: Text(
            '플랜을 불러오는데 실패했습니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ),
      data: (plan) {
        if (plan == null) {
          return Scaffold(
            backgroundColor: AppColors.background(context),
            appBar: AppBar(backgroundColor: AppColors.background(context)),
            body: Center(
              child: Text(
                '플랜을 찾을 수 없습니다',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          );
        }
        return _buildContent(context, ref, plan);
      },
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, TrainingPlan plan) {
    final isActive = plan.status == 'active';

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: Text(
          '플랜 상세',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
            ),
            color: AppColors.surface(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            ),
            onSelected: (value) {
              switch (value) {
                case 'complete':
                  _showConfirmDialog(
                    context,
                    ref: ref,
                    title: '플랜 완료',
                    message: '이 플랜을 완료 처리하시겠습니까?',
                    onConfirm: () async {
                      await ref.read(planProvider.notifier).completePlan(plan.id);
                      if (context.mounted) context.pop();
                    },
                  );
                  break;
                case 'cancel':
                  _showConfirmDialog(
                    context,
                    ref: ref,
                    title: '플랜 취소',
                    message: '이 플랜을 취소하시겠습니까? 취소된 플랜은 복구할 수 없습니다.',
                    isDestructive: true,
                    onConfirm: () async {
                      await ref.read(planProvider.notifier).cancelPlan(plan.id);
                      if (context.mounted) context.pop();
                    },
                  );
                  break;
                case 'delete':
                  _showConfirmDialog(
                    context,
                    ref: ref,
                    title: '플랜 삭제',
                    message: '이 플랜을 삭제하시겠습니까? 삭제된 플랜은 복구할 수 없습니다.',
                    isDestructive: true,
                    onConfirm: () async {
                      await ref.read(planProvider.notifier).deletePlan(plan.id);
                      ref.invalidate(userPlansProvider);
                      if (context.mounted) context.pop();
                    },
                  );
                  break;
              }
            },
            itemBuilder: (context) => [
              // 활성 플랜만 완료/취소 가능
              if (isActive) ...[
                PopupMenuItem(
                  value: 'complete',
                  child: Text(
                    '플랜 완료',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                ),
                PopupMenuItem(
                  value: 'cancel',
                  child: Text(
                    '플랜 취소',
                    style: AppTypography.body.copyWith(
                      color: AppColors.warning,
                    ),
                  ),
                ),
              ],
              // 삭제는 항상 가능
              PopupMenuItem(
                value: 'delete',
                child: Text(
                  '플랜 삭제',
                  style: AppTypography.body.copyWith(
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),

              // 플랜 기본 정보 카드
              _buildInfoCard(context, plan),
              const SizedBox(height: AppSpacing.lg),

              // 목표 카드
              _buildGoalCard(context, plan),
              const SizedBox(height: AppSpacing.lg),

              // 페이스 존 표시
              if (plan.paceZones != null) ...[
                _buildPaceZonesCard(context, plan),
                const SizedBox(height: AppSpacing.lg),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  /// 플랜 기본 정보 카드
  Widget _buildInfoCard(BuildContext context, TrainingPlan plan) {
    return Container(
      width: double.infinity,
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
              Expanded(
                child: Text(
                  plan.planName,
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
              ),
              _buildStatusBadge(context, plan.status),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(
            context,
            icon: Icons.calendar_today_rounded,
            label: '기간',
            value:
                '${_formatDate(plan.startDate)} ~ ${_formatDate(plan.endDate)}',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildInfoRow(
            context,
            icon: Icons.repeat_rounded,
            label: '총 주차',
            value: '${plan.totalWeeks}주',
          ),
          if (plan.vdotScore != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow(
              context,
              icon: Icons.analytics_outlined,
              label: '생성 시 VDOT',
              value: plan.vdotScore!.toStringAsFixed(1),
            ),
          ],
        ],
      ),
    );
  }

  /// 목표 카드
  Widget _buildGoalCard(BuildContext context, TrainingPlan plan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '목표',
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildInfoRow(
            context,
            icon: Icons.straighten_rounded,
            label: '목표 거리',
            value: _formatDistance(plan.goalDistanceKm),
          ),
          if (plan.goalTimeSeconds != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildInfoRow(
              context,
              icon: Icons.timer_outlined,
              label: '목표 시간',
              value: TimeFormatter.toHHMMSS(plan.goalTimeSeconds!),
            ),
          ],
        ],
      ),
    );
  }

  /// 페이스 존 카드
  Widget _buildPaceZonesCard(BuildContext context, TrainingPlan plan) {
    final PaceZones paceZones;
    try {
      paceZones = PaceZones.fromJson(plan.paceZones!);
    } catch (_) {
      return const SizedBox.shrink();
    }

    String formatPace(int secondsPerKm) {
      final m = secondsPerKm ~/ 60;
      final s = secondsPerKm % 60;
      return '$m:${s.toString().padLeft(2, '0')}/km';
    }

    final zones = [
      (label: '이지런', color: const Color(0xFF34C759), pace: '${formatPace(paceZones.easyFastPace)} ~ ${formatPace(paceZones.easySlowPace)}'),
      (label: '마라톤페이스', color: const Color(0xFF007AFF), pace: formatPace(paceZones.marathonPace)),
      (label: '템포런', color: const Color(0xFFFF9F0A), pace: formatPace(paceZones.thresholdPace)),
      (label: '인터벌', color: const Color(0xFFFF6B35), pace: formatPace(paceZones.intervalPace)),
      (label: '반복달리기', color: const Color(0xFFFF3B30), pace: formatPace(paceZones.repetitionPace)),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '페이스 존',
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          ...zones.map((z) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: z.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 90,
                  child: Text(
                    z.label,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    z.pace,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            style: AppTypography.body.copyWith(
              color: AppColors.textPrimary(context),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status) {
      case 'active':
        bgColor = AppColors.success.withValues(alpha: 0.15);
        textColor = AppColors.success;
        label = '활성';
        break;
      case 'completed':
        bgColor = AppColors.primary(context).withValues(alpha: 0.15);
        textColor = AppColors.primary(context);
        label = '완료';
        break;
      case 'cancelled':
        bgColor = AppColors.textSecondary.withValues(alpha: 0.15);
        textColor = AppColors.textSecondary;
        label = '취소';
        break;
      default:
        bgColor = AppColors.textSecondary.withValues(alpha: 0.15);
        textColor = AppColors.textSecondary;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
      ),
      child: Text(
        label,
        style: AppTypography.bodySmall.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context, {
    required WidgetRef ref,
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
    bool isDestructive = false,
  }) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text(
          title,
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          message,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '취소',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onConfirm();
            },
            child: Text(
              '확인',
              style: AppTypography.body.copyWith(
                color: isDestructive
                    ? AppColors.error
                    : AppColors.primary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double km) {
    if (km == 5.0) return '5K';
    if (km == 10.0) return '10K';
    if (km == 21.0975) return '하프 마라톤 (21.1km)';
    if (km == 42.195) return '풀 마라톤 (42.195km)';
    return '${km.toStringAsFixed(1)}km';
  }
}
