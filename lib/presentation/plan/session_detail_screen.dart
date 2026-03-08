import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../common/widgets/training_session_card.dart';
import '../common/widgets/training_type_badge.dart';
import '../common/widgets/weather_adjustment_card.dart';
import '../providers/coaching_providers.dart';
import '../providers/data_providers.dart';
import 'providers/plan_provider.dart';

/// D-1 훈련 세션 상세 화면
class SessionDetailScreen extends ConsumerWidget {
  final String sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionByIdProvider(sessionId));
    final weekNumber = ref.watch(sessionWeekNumberProvider(sessionId));

    if (session == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          backgroundColor: AppColors.background(context),
        ),
        body: Center(
          child: Text(
            '세션을 찾을 수 없습니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    final zone = TrainingZones.fromType(session.zoneType);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: Text(
          '훈련 상세',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
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

              // 날짜 + 주차 정보
              if (weekNumber != null)
                Text(
                  '${session.dayLabel}요일  |  $weekNumber주차',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              const SizedBox(height: AppSpacing.sm),

              // 훈련 유형 배지 + 제목
              Row(
                children: [
                  TrainingTypeBadge(zone: zone),
                  const SizedBox(width: AppSpacing.sm),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                session.title,
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // 목표 카드
              _buildGoalCard(context, session),

              const SizedBox(height: AppSpacing.lg),

              // 날씨 기반 페이스 보정 카드
              _buildWeatherAdjustmentSection(context, ref, session),

              const SizedBox(height: AppSpacing.lg),

              // 코치 설명
              _buildCoachDescription(context, session),

              // 인터벌인 경우 워크아웃 상세
              if (session.workoutDetail != null) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildWorkoutDetail(context, session),
              ],

              const SizedBox(height: AppSpacing.lg),

              // 실제 운동 기록 영역 (Phase 4 이후)
              _buildActualRecordPlaceholder(context),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  /// 목표 카드
  Widget _buildGoalCard(BuildContext context, DaySession session) {
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

          // 거리
          if (session.distanceKm != null)
            _buildGoalRow(
              context,
              icon: Icons.straighten_rounded,
              label: '거리',
              value: '${session.distanceKm!.toStringAsFixed(0)}km',
            ),

          // 페이스
          if (session.targetPace != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildGoalRow(
              context,
              icon: Icons.speed_rounded,
              label: '페이스',
              value: session.targetPace ?? '',
            ),
          ],

          // 예상 시간
          if (session.estimatedTime != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildGoalRow(
              context,
              icon: Icons.timer_outlined,
              label: '예상 시간',
              value: session.estimatedTime!,
            ),
          ],
        ],
      ),
    );
  }

  /// 목표 카드 내 행
  Widget _buildGoalRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          label,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// 날씨 기반 페이스 보정 섹션
  ///
  /// 세션 날짜에 따라 분기:
  /// - 오늘 세션 (미완료): 실시간 날씨 보정 표시
  /// - 완료된 세션 (workout_log 있음): 저장된 보정 이력 표시
  /// - 미래 세션: 안내 문구
  /// - 과거 세션 (workout 없음): 미표시
  Widget _buildWeatherAdjustmentSection(
    BuildContext context,
    WidgetRef ref,
    DaySession session,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sessionDay = DateTime(
      session.sessionDate.year,
      session.sessionDate.month,
      session.sessionDate.day,
    );

    final isToday = sessionDay == today;
    final isFuture = sessionDay.isAfter(today);
    final isCompleted = session.status == SessionStatus.completed ||
        session.status == SessionStatus.partial;

    // 완료된 세션: 저장된 날씨 컨텍스트 표시
    if (isCompleted) {
      return _buildCompletedWeatherSection(context, ref, session);
    }

    // 오늘 세션 (미완료): 실시간 날씨 보정
    if (isToday) {
      return _buildLiveWeatherSection(context, ref, session);
    }

    // 미래 세션: 안내 문구
    if (isFuture) {
      return const WeatherFutureCard();
    }

    // 과거 세션 (미완료, workout 없음): 미표시
    return const SizedBox.shrink();
  }

  /// 실시간 날씨 보정 (오늘 세션용)
  Widget _buildLiveWeatherSection(
    BuildContext context,
    WidgetRef ref,
    DaySession session,
  ) {
    final adjustmentAsync = ref.watch(
      weatherPaceAdjustmentProvider(
        (sessionId: session.id, targetPace: session.targetPace),
      ),
    );

    return adjustmentAsync.when(
      loading: () => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Row(
          children: [
            Icon(
              Icons.thermostat_rounded,
              size: 24,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                '날씨 정보 확인 중...',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (result) {
        if (result == null) return const SizedBox.shrink();
        return WeatherAdjustmentCard(
          result: result,
          originalPace: session.targetPace,
        );
      },
    );
  }

  /// 완료된 세션의 날씨 이력 표시
  Widget _buildCompletedWeatherSection(
    BuildContext context,
    WidgetRef ref,
    DaySession session,
  ) {
    final workoutAsync = ref.watch(workoutLogBySessionProvider(session.id));

    return workoutAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (workout) {
        if (workout == null || workout.weatherContext == null) {
          return const SizedBox.shrink();
        }
        return WeatherHistoryCard(
          weatherContext: workout.weatherContext!,
          actualPaceSecondsPerKm: workout.avgPaceSecondsPerKm,
        );
      },
    );
  }

  /// 코치 설명 카드
  Widget _buildCoachDescription(BuildContext context, DaySession session) {
    // description이 없으면 기본 메시지 표시
    final description = session.description ??
        _getDefaultDescription(session.zoneType);

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
              Icon(
                Icons.smart_toy_outlined,
                size: 20,
                color: AppColors.primary(context),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '코치 설명',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            description,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  /// 인터벌 워크아웃 상세
  Widget _buildWorkoutDetail(BuildContext context, DaySession session) {
    final detail = session.workoutDetail!;
    final warmup = detail['warmup'] as Map<String, dynamic>?;
    final intervals = detail['intervals'] as List<dynamic>?;
    final cooldown = detail['cooldown'] as Map<String, dynamic>?;

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
            '워크아웃 구성',
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // 워밍업
          if (warmup != null)
            _buildWorkoutPhase(
              context,
              phase: '워밍업',
              detail: '${warmup['distance_km']}km @ ${warmup['pace']}/km',
              color: TrainingZones.easyColor,
            ),

          // 인터벌 세트
          if (intervals != null)
            for (final interval in intervals) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildWorkoutPhase(
                context,
                phase: '인터벌',
                detail:
                    '${interval['reps']}x${interval['distance_m']}m @ ${interval['pace']}/km\n리커버리: ${interval['rest_m']}m @ ${interval['rest_pace']}/km',
                color: TrainingZones.intervalColor,
              ),
            ],

          // 쿨다운
          if (cooldown != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWorkoutPhase(
              context,
              phase: '쿨다운',
              detail: '${cooldown['distance_km']}km @ ${cooldown['pace']}/km',
              color: TrainingZones.easyColor,
            ),
          ],
        ],
      ),
    );
  }

  /// 워크아웃 단계 아이템
  Widget _buildWorkoutPhase(
    BuildContext context, {
    required String phase,
    required String detail,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 4,
          height: 40,
          margin: const EdgeInsets.only(top: 2),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                phase,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                detail,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// 실제 운동 기록 영역 placeholder (Phase 4 이후)
  Widget _buildActualRecordPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.divider(context),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.fitness_center_rounded,
            size: 32,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '실제 운동 기록',
            style: AppTypography.h3.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'HealthKit/Strava 연동 후 실제 운동 데이터가 여기에 표시됩니다',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getDefaultDescription(TrainingZoneType zoneType) {
    switch (zoneType) {
      case TrainingZoneType.easy:
        return '편안한 페이스로 달리세요. 대화가 가능한 속도를 유지하는 것이 핵심입니다. 유산소 기초 체력을 향상시키는 훈련입니다.';
      case TrainingZoneType.marathon:
        return '마라톤 목표 페이스로 달리세요. 이 페이스에 익숙해지는 것이 중요합니다. 꾸준한 리듬을 유지하세요.';
      case TrainingZoneType.threshold:
        return '젖산 역치 페이스로 달리세요. "편안하게 힘든" 정도의 강도입니다. 이 훈련은 속도 지구력을 향상시킵니다.';
      case TrainingZoneType.interval:
        return '인터벌 훈련입니다. 빠른 구간과 회복 구간을 반복합니다. VO2max를 향상시키는 핵심 훈련입니다.';
      case TrainingZoneType.repetition:
        return '반복 훈련입니다. 짧은 거리를 빠른 페이스로 달립니다. 러닝 이코노미와 스피드를 향상시킵니다.';
      case TrainingZoneType.longRun:
        return '장거리런입니다. 이지런 페이스로 긴 거리를 달리세요. 근지구력과 정신력을 키우는 중요한 훈련입니다.';
      case TrainingZoneType.recovery:
        return '가벼운 회복런입니다. 이지런보다 더 느린 페이스로 편안하게 달리세요. 근육 회복을 돕는 활동적 휴식입니다.';
      case TrainingZoneType.crossTraining:
        return '크로스 트레이닝입니다. 수영, 자전거, 근력 운동 등 러닝 외 활동으로 전체적인 체력을 보완합니다.';
      case TrainingZoneType.rest:
        return '오늘은 휴식일입니다. 충분한 수분 섭취와 스트레칭으로 회복에 집중하세요.';
    }
  }
}
