import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/pace_formatter.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/workout_log.dart';
import '../../data/services/weather_service.dart';
import '../common/widgets/coaching_message_card.dart';
import '../common/widgets/skeleton.dart';
import '../common/widgets/progress_bar.dart';
import '../common/widgets/training_session_card.dart';
import '../common/widgets/weather_card.dart';
import '../providers/data_providers.dart';
import '../providers/strava_sync_provider.dart';
import 'providers/home_provider.dart';

/// C-1 홈 화면 (오늘의 훈련)
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _syncTriggered = false;

  @override
  Widget build(BuildContext context) {
    final homeAsync = ref.watch(homeStateProvider);
    final syncState = ref.watch(stravaSyncProvider);

    // homeState 로드 완료 시 동기화 트리거
    if (homeAsync.hasValue && !_syncTriggered) {
      _syncTriggered = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        ref.read(stravaSyncProvider.notifier).syncIfNeeded();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Column(
        children: [
          // 동기화 중 표시
          if (syncState.isSyncing)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.xs,
              ),
              color: AppColors.primary(context).withValues(alpha: 0.1),
              child: SafeArea(
                bottom: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary(context),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '데이터 동기화 중...',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.primary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: homeAsync.when(
              loading: () => const SingleChildScrollView(
                child: HomeScreenSkeleton(),
              ),
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
          ),
        ],
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

            // 날씨 카드
            _buildWeatherSection(context, ref),
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
              _buildTodaySessionCard(context, state.todaySession!)
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
                          '${state.weeklyProgress!.completedKm.toStringAsFixed(1)}km / ${state.weeklyProgress!.totalKm.toStringAsFixed(1)}km',
                      rightLabel:
                          '${(state.weeklyProgress!.distanceProgress * 100).toInt()}%',
                      progress: state.weeklyProgress!.distanceProgress,
                    ),
                  ],
                ),
              ),

            const SizedBox(height: AppSpacing.xl),

            // 최근 운동 기록 섹션
            if (state.recentWorkouts.isNotEmpty) ...[
              Text(
                '최근 운동',
                style: AppTypography.h2.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _buildRecentWorkouts(context, state.recentWorkouts),
              const SizedBox(height: AppSpacing.xl),
            ],

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
              )
            else
              _buildNoCoachingCard(context),

            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }

  /// 오늘의 훈련 카드 (완료 여부에 따라 다르게 표시)
  Widget _buildTodaySessionCard(
    BuildContext context,
    TodaySession session,
  ) {
    final zone = TrainingZones.fromType(session.zoneType);

    if (session.isCompleted && session.workoutLog != null) {
      // 완료된 경우: 실제 기록 표시
      return _buildCompletedSessionCard(context, session, zone);
    }

    // 미완료: 기존 세션 카드
    return TrainingSessionCard(
      zone: zone,
      title: session.title,
      targetPace: session.targetPace,
      estimatedTime: session.estimatedTime,
      status: session.isCompleted
          ? SessionStatus.completed
          : SessionStatus.pending,
      onTap: () {
        context.push('/plan/session/${session.id}');
      },
    );
  }

  /// 완료된 세션: 실제 기록 표시
  Widget _buildCompletedSessionCard(
    BuildContext context,
    TodaySession session,
    TrainingZone zone,
  ) {
    final workout = session.workoutLog!;
    final paceStr = workout.avgPaceSecondsPerKm != null
        ? PaceFormatter.toDisplay(workout.avgPaceSecondsPerKm!)
        : '-';
    final durationStr = TimeFormatter.toReadable(workout.durationSeconds);

    return GestureDetector(
      onTap: () {
        context.push('/records/${workout.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Row(
          children: [
            // 좌측 컬러 바
            Container(
              width: 4,
              height: 72,
              decoration: BoxDecoration(
                color: zone.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            // 내용
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.15),
                          borderRadius:
                              BorderRadius.circular(AppSpacing.badgeRadius),
                        ),
                        child: Text(
                          '완료',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        session.title,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 실제 기록 표시
                  Row(
                    children: [
                      _buildMiniStat(
                        context,
                        '${workout.distanceKm.toStringAsFixed(1)}km',
                      ),
                      const SizedBox(width: AppSpacing.md),
                      _buildMiniStat(context, durationStr),
                      const SizedBox(width: AppSpacing.md),
                      _buildMiniStat(context, paceStr),
                    ],
                  ),
                  if (workout.avgHeartRate != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        const Icon(
                          Icons.favorite,
                          color: AppColors.error,
                          size: 14,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${workout.avgHeartRate}bpm',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // 완료 아이콘
            const Icon(
              Icons.check_circle,
              color: AppColors.success,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  /// 미니 통계 텍스트
  Widget _buildMiniStat(BuildContext context, String text) {
    return Text(
      text,
      style: AppTypography.body.copyWith(
        color: AppColors.textPrimary(context),
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// 최근 운동 기록 리스트 (테이블 형태)
  Widget _buildRecentWorkouts(
    BuildContext context,
    List<WorkoutLog> workouts,
  ) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          // 헤더
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text(
                    '날짜',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    '거리',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    '페이스',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                Expanded(
                  child: Text(
                    '시간',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
                const SizedBox(width: 20),
              ],
            ),
          ),
          Divider(
            color: AppColors.divider(context),
            height: 1,
          ),
          // 데이터 행
          ...workouts.asMap().entries.map((entry) {
            final index = entry.key;
            final workout = entry.value;
            final date = workout.workoutDate;
            final dateStr =
                '${date.month}/${date.day}(${_weekdayShort(date.weekday)})';
            final distanceStr =
                '${workout.distanceKm.toStringAsFixed(1)}km';
            final paceStr = workout.avgPaceSecondsPerKm != null
                ? '${PaceFormatter.toMMSS(workout.avgPaceSecondsPerKm!)}/km'
                : '-';
            final durationStr =
                TimeFormatter.toReadable(workout.durationSeconds);

            return Column(
              children: [
                if (index > 0)
                  Divider(
                    color: AppColors.divider(context),
                    height: 1,
                  ),
                GestureDetector(
                  onTap: () {
                    context.push('/records/${workout.id}');
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm + 2,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: Text(
                            dateStr,
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            distanceStr,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            paceStr,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            durationStr,
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  /// 날씨 카드 (실시간 데이터)
  Widget _buildWeatherSection(BuildContext context, WidgetRef ref) {
    final weatherAsync = ref.watch(currentWeatherProvider);

    return weatherAsync.when(
      loading: () => const WeatherCard(
        weatherEmoji: '🌤️',
        temperature: '--°C',
        condition: '날씨 확인 중...',
        message: '',
      ),
      error: (_, __) => const WeatherCard(
        weatherEmoji: '🌤️',
        temperature: '--°C',
        condition: '날씨 정보 없음',
        message: '위치 권한을 허용하면 날씨 기반 코칭을 받을 수 있어요',
      ),
      data: (weather) {
        if (weather == null) {
          return const WeatherCard(
            weatherEmoji: '🌤️',
            temperature: '--°C',
            condition: '날씨 정보 없음',
            message: '위치 권한을 허용하면 날씨 기반 코칭을 받을 수 있어요',
          );
        }
        final emoji = WeatherService.getWeatherEmoji(weather.iconCode);
        final description = WeatherService.getWeatherDescription(weather);
        return WeatherCard(
          weatherEmoji: emoji,
          temperature: '${weather.temperatureC.toStringAsFixed(0)}°C',
          condition: weather.conditionDetail,
          message: description,
        );
      },
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
                color: AppColors.primary(context).withValues(alpha: 0.3),
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
            color: AppColors.textSecondary.withValues(alpha: 0.5),
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
            color: AppColors.textSecondary.withValues(alpha: 0.5),
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

  String _weekdayShort(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}
