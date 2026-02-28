import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../common/widgets/progress_bar.dart';
import '../common/widgets/training_session_card.dart';
import '../common/widgets/training_type_badge.dart';
import 'providers/plan_provider.dart';

/// C-2 플랜 화면 (훈련표)
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final planState = ref.watch(planProvider);

    if (planState.isLoading) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: const Text('훈련표')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!planState.hasPlan) {
      return _buildEmptyState(context);
    }

    return _buildPlanContent(context, ref, planState);
  }

  /// 플랜이 없을 때 빈 상태
  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '훈련표',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_month_rounded,
                size: 80,
                color: AppColors.primary(context).withOpacity(0.3),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                '아직 생성된 훈련표가 없습니다',
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'AI가 맞춤 훈련 플랜을 만들어 드립니다',
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

  /// 플랜이 있을 때 훈련표 컨텐츠
  Widget _buildPlanContent(
    BuildContext context,
    WidgetRef ref,
    PlanScreenState planState,
  ) {
    final plan = planState.activePlan!;
    final currentWeek = planState.currentWeek;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '훈련표',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
        actions: [
          IconButton(
            icon: Icon(
              Icons.info_outline_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () {
              context.push('/plan/detail/${plan.id}');
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 플랜 이름 + 상태
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        plan.name,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.textPrimary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.badgeRadius),
                      ),
                      child: Text(
                        '활성',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // 주차 네비게이션
              if (currentWeek != null) ...[
                _buildWeekNavigation(context, ref, planState, currentWeek),
                const SizedBox(height: AppSpacing.lg),

                // 일별 훈련 목록
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Column(
                    children: currentWeek.sessions.map((session) {
                      // dayOfWeek: 1=월 ~ 7=일, startDate는 월요일
                      final sessionDate = currentWeek.startDate
                          .add(Duration(days: session.dayOfWeek - 1));
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildDaySessionRow(
                            context, session, sessionDate),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // 주간 달성률
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.screenPadding,
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '주간 목표',
                          style: AppTypography.h3.copyWith(
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        ProgressBar(
                          leftLabel:
                              '${currentWeek.completedKm.toStringAsFixed(0)}km / ${currentWeek.targetKm.toStringAsFixed(0)}km',
                          rightLabel:
                              '${(currentWeek.progress * 100).toInt()}%',
                          progress: currentWeek.progress,
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/plan/create'),
        backgroundColor: AppColors.primary(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  /// 주차 네비게이션 위젯
  Widget _buildWeekNavigation(
    BuildContext context,
    WidgetRef ref,
    PlanScreenState planState,
    WeekData currentWeek,
  ) {
    final notifier = ref.read(planProvider.notifier);
    final canGoPrev = planState.currentWeekIndex > 0;
    final canGoNext = planState.currentWeekIndex < planState.weeks.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
        vertical: AppSpacing.md,
      ),
      color: AppColors.surface(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: canGoPrev ? notifier.goToPreviousWeek : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: canGoPrev
                  ? AppColors.textPrimary(context)
                  : AppColors.textDisabled(context),
            ),
          ),
          Column(
            children: [
              Text(
                '${currentWeek.weekNumber}주차 (${currentWeek.phaseLabel})',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${_formatDate(currentWeek.startDate)} ~ ${_formatDate(currentWeek.endDate)}',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: canGoNext ? notifier.goToNextWeek : null,
            icon: Icon(
              Icons.chevron_right_rounded,
              color: canGoNext
                  ? AppColors.textPrimary(context)
                  : AppColors.textDisabled(context),
            ),
          ),
        ],
      ),
    );
  }

  /// 일별 세션 행 위젯
  Widget _buildDaySessionRow(
      BuildContext context, DaySession session, DateTime sessionDate) {
    final isRest = session.zoneType == TrainingZoneType.rest;
    final zone = TrainingZones.fromType(session.zoneType);
    final dateLabel = '${sessionDate.month}/${sessionDate.day}';

    return GestureDetector(
      onTap: isRest
          ? null
          : () => context.push('/plan/session/${session.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Row(
          children: [
            // 요일 + 날짜
            SizedBox(
              width: 44,
              child: Column(
                children: [
                  Text(
                    session.dayLabel,
                    style: AppTypography.h3.copyWith(
                      color: isRest
                          ? AppColors.textSecondary
                          : AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dateLabel,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),

            // 좌측 컬러 바
            if (!isRest) ...[
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: zone.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],

            // 훈련 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isRest)
                    Row(
                      children: [
                        TrainingTypeBadge(zone: zone),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            session.title,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    )
                  else
                    Text(
                      session.title,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  if (session.distanceKm != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${session.distanceKm!.toStringAsFixed(0)}km',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 상태 아이콘
            _buildStatusIcon(session.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(SessionStatus status) {
    switch (status) {
      case SessionStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: AppColors.success,
          size: 22,
        );
      case SessionStatus.pending:
        return const Icon(
          Icons.radio_button_unchecked,
          color: AppColors.textSecondary,
          size: 22,
        );
      case SessionStatus.missed:
      case SessionStatus.skipped:
        return const Icon(
          Icons.warning_amber_rounded,
          color: AppColors.warning,
          size: 22,
        );
      case SessionStatus.partial:
        return const Icon(
          Icons.check_circle_outline,
          color: AppColors.warning,
          size: 22,
        );
      case SessionStatus.rest:
        return Icon(
          Icons.remove,
          color: AppColors.textSecondary.withOpacity(0.5),
          size: 22,
        );
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}(${_weekdayShort(date.weekday)})';
  }

  String _weekdayShort(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}
