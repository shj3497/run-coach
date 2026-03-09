import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/pace_formatter.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/workout_log.dart';
import '../common/widgets/stat_card.dart';
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

              // 워크아웃 구성 (상세 구간이 있을 때만)
              if (_hasWorkoutStructure(session.workoutDetail)) ...[
                const SizedBox(height: AppSpacing.lg),
                _buildWorkoutDetail(context, session),
              ],

              const SizedBox(height: AppSpacing.lg),

              // 날씨 기반 페이스 보정 카드
              _buildWeatherAdjustmentSection(context, ref, session),

              const SizedBox(height: AppSpacing.lg),

              // 코치 설명
              _buildCoachDescription(context, session),

              const SizedBox(height: AppSpacing.lg),

              // 실제 운동 기록 영역
              _buildActualRecordSection(context, ref, session),

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

          // 페이스 (인터벌/반복은 워크아웃 구성에서 상세 표시)
          if (session.targetPace != null &&
              session.zoneType != TrainingZoneType.interval &&
              session.zoneType != TrainingZoneType.repetition) ...[
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

  /// 워크아웃 상세 (템포/인터벌 모두 지원)
  Widget _buildWorkoutDetail(BuildContext context, DaySession session) {
    final detail = session.workoutDetail!;
    final warmup = detail['warmup'] as Map<String, dynamic>?;
    final main = detail['main'] as Map<String, dynamic>?;
    final intervals = detail['intervals'] as List<dynamic>?;
    final cooldown = detail['cooldown'] as Map<String, dynamic>?;

    // 메인 구간의 컬러/라벨 결정
    final mainColor = switch (session.zoneType) {
      TrainingZoneType.threshold => TrainingZones.thresholdColor,
      TrainingZoneType.marathon => TrainingZones.marathonColor,
      TrainingZoneType.interval => TrainingZones.intervalColor,
      TrainingZoneType.repetition => TrainingZones.repetitionColor,
      _ => TrainingZones.easyColor,
    };
    final mainLabel = switch (session.zoneType) {
      TrainingZoneType.threshold => '템포런',
      TrainingZoneType.marathon => '마라톤페이스',
      TrainingZoneType.interval => '인터벌',
      TrainingZoneType.repetition => '반복달리기',
      _ => '메인',
    };

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
              detail:
                  '${warmup['distance_km']}km @ ${_formatPace(warmup['pace'])}',
              color: TrainingZones.easyColor,
            ),

          // 메인 구간 (템포/마라톤페이스)
          if (main != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWorkoutPhase(
              context,
              phase: mainLabel,
              detail:
                  '${main['distance_km']}km @ ${_formatPace(main['pace'])}',
              color: mainColor,
            ),
          ],

          // 인터벌 세트
          if (intervals != null)
            for (final interval in intervals) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildWorkoutPhase(
                context,
                phase: mainLabel,
                detail:
                    '${interval['reps']}x${interval['distance_m']}m @ ${_formatPace(interval['pace'])}\n리커버리: ${interval['rest_m']}m @ ${_formatPace(interval['rest_pace'])}',
                color: mainColor,
              ),
            ],

          // 쿨다운
          if (cooldown != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildWorkoutPhase(
              context,
              phase: '쿨다운',
              detail:
                  '${cooldown['distance_km']}km @ ${_formatPace(cooldown['pace'])}',
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

  /// 실제 운동 기록 섹션
  Widget _buildActualRecordSection(
    BuildContext context,
    WidgetRef ref,
    DaySession session,
  ) {
    final workoutAsync = ref.watch(workoutLogBySessionProvider(session.id));

    return workoutAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (workout) {
        if (workout == null) return _buildNoRecordPlaceholder(context);
        return _buildActualRecordCard(context, session, workout);
      },
    );
  }

  /// 기록 없음 placeholder
  Widget _buildNoRecordPlaceholder(BuildContext context) {
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

  /// 실제 운동 기록 카드 (탭하면 워크아웃 상세로 이동)
  Widget _buildActualRecordCard(
    BuildContext context,
    DaySession session,
    WorkoutLog workout,
  ) {
    final paceStr = workout.avgPaceSecondsPerKm != null
        ? PaceFormatter.toMMSS(workout.avgPaceSecondsPerKm!)
        : '-';
    final durationStr = TimeFormatter.toReadable(workout.durationSeconds);

    return GestureDetector(
      onTap: () => context.push('/records/${workout.id}'),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더: 제목 + 소스 + 화살표
            Row(
              children: [
                Icon(
                  Icons.directions_run_rounded,
                  size: 20,
                  color: AppColors.primary(context),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '실제 운동 기록',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const Spacer(),
                // 데이터 소스
                if (workout.source == 'strava') ...[
                  Text(
                    'Strava',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('\u{1F536}', style: TextStyle(fontSize: 10)),
                ] else ...[
                  Text(
                    'HealthKit',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.favorite,
                    color: AppColors.error,
                    size: 12,
                  ),
                ],
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.md),

            // 핵심 지표 2x2
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: '거리',
                    value: workout.distanceKm.toStringAsFixed(1),
                    unit: 'km',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    label: '시간',
                    value: durationStr,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: '평균 페이스',
                    value: paceStr,
                    unit: workout.avgPaceSecondsPerKm != null ? '/km' : '',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: StatCard(
                    label: '평균 심박수',
                    value: workout.avgHeartRate != null
                        ? '${workout.avgHeartRate}'
                        : '-',
                    unit: workout.avgHeartRate != null ? 'bpm' : '',
                  ),
                ),
              ],
            ),

            // 목표 대비 달성률
            if (session.distanceKm != null && session.distanceKm! > 0) ...[
              const SizedBox(height: AppSpacing.md),
              _buildAchievementRow(
                context,
                targetKm: session.distanceKm!,
                actualKm: workout.distanceKm,
              ),
            ],

            // 추가 정보 (있을 때만)
            if (workout.totalCalories != null ||
                workout.totalElevationGainM != null ||
                workout.avgCadence != null) ...[
              const SizedBox(height: AppSpacing.md),
              Divider(color: AppColors.divider(context), height: 1),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.lg,
                runSpacing: AppSpacing.sm,
                children: [
                  if (workout.totalCalories != null)
                    _buildMiniStat(
                      context,
                      icon: Icons.local_fire_department_rounded,
                      label: '${workout.totalCalories} kcal',
                    ),
                  if (workout.totalElevationGainM != null)
                    _buildMiniStat(
                      context,
                      icon: Icons.terrain_rounded,
                      label:
                          '${workout.totalElevationGainM!.toStringAsFixed(0)}m',
                    ),
                  if (workout.avgCadence != null)
                    _buildMiniStat(
                      context,
                      icon: Icons.speed_rounded,
                      label: '${workout.avgCadence} spm',
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 목표 대비 달성률 행
  Widget _buildAchievementRow(
    BuildContext context, {
    required double targetKm,
    required double actualKm,
  }) {
    final ratio = actualKm / targetKm;
    final percent = (ratio * 100).round();

    final Color color;
    final String statusText;
    final IconData icon;

    if (ratio >= 0.8) {
      color = AppColors.success;
      statusText = '달성';
      icon = Icons.check_circle_rounded;
    } else if (ratio >= 0.5) {
      color = AppColors.warning;
      statusText = '부분 달성';
      icon = Icons.remove_circle_rounded;
    } else {
      color = AppColors.textSecondary;
      statusText = '미달성';
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '목표 대비: 거리 $percent% $statusText',
            style: AppTypography.bodySmall.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 추가 정보 미니 스탯
  Widget _buildMiniStat(
    BuildContext context, {
    required IconData icon,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  /// warmup/main/intervals 중 하나라도 있으면 워크아웃 구성 표시
  bool _hasWorkoutStructure(Map<String, dynamic>? detail) {
    if (detail == null) return false;
    return detail.containsKey('warmup') ||
        detail.containsKey('main') ||
        detail.containsKey('intervals');
  }

  /// LLM이 "5:34/km" 또는 "5:34" 어느 형태로든 줄 수 있으므로 정규화
  String _formatPace(dynamic pace) {
    final s = pace?.toString() ?? '';
    if (s.contains('/km')) return s;
    return '$s/km';
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
