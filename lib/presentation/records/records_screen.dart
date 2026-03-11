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
import '../common/widgets/skeleton.dart';
import '../common/widgets/stat_card.dart';
import '../common/widgets/training_type_badge.dart';
import '../providers/strava_sync_provider.dart';
import 'providers/records_provider.dart';

/// C-3 기록 화면 (운동 기록)
/// 실제 workout_repository 연동
class RecordsScreen extends ConsumerStatefulWidget {
  const RecordsScreen({super.key});

  @override
  ConsumerState<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends ConsumerState<RecordsScreen> {
  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      ref.read(stravaSyncProvider.notifier).syncIfNeeded();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasRecords = ref.watch(hasRecordsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final recordsAsync = ref.watch(workoutRecordsProvider);
    final selectedMonth = ref.watch(selectedMonthProvider);

    // 동기화 성공 시 기록 provider 무효화
    ref.listen<StravaSyncState>(stravaSyncProvider, (prev, next) {
      if (prev?.status != StravaSyncStatus.success &&
          next.status == StravaSyncStatus.success &&
          next.newWorkoutsCount > 0) {
        ref.invalidate(monthlySummaryProvider);
        ref.invalidate(workoutRecordsProvider);
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '운동 기록',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
        elevation: 0,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _onRefresh,
          color: AppColors.primary(context),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // 월 선택 네비게이션
                _buildMonthSelector(context, ref, selectedMonth),
                const SizedBox(height: AppSpacing.lg),

                // 월간 요약 카드
                Text(
                  '${selectedMonth.isCurrentMonth ? "이번 달" : "${selectedMonth.month}월"} 요약',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _buildMonthlySummary(context, summaryAsync),
                const SizedBox(height: AppSpacing.xl),

                // 운동 기록 리스트
                Text(
                  '운동 기록',
                  style: AppTypography.h2.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                if (!hasRecords)
                  _buildEmptyRecords(context)
                else
                  _buildRecordsList(context, recordsAsync),

                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Pull-to-refresh: Strava 강제 동기화 + 데이터 새로고침
  Future<void> _onRefresh() async {
    debugPrint('[Records] _onRefresh called');
    await ref.read(stravaSyncProvider.notifier).forceSync();
    debugPrint('[Records] forceSync completed');
    ref.invalidate(monthlySummaryProvider);
    ref.invalidate(workoutRecordsProvider);
  }

  /// 월 선택 네비게이션 (좌화살표, 월 표시, 우화살표)
  Widget _buildMonthSelector(
    BuildContext context,
    WidgetRef ref,
    SelectedMonth selectedMonth,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              ref.read(selectedMonthProvider.notifier).state =
                  selectedMonth.previous;
            },
            icon: Icon(
              Icons.chevron_left_rounded,
              color: AppColors.textPrimary(context),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          Text(
            selectedMonth.displayLabel,
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          IconButton(
            onPressed: selectedMonth.isCurrentMonth
                ? null
                : () {
                    ref.read(selectedMonthProvider.notifier).state =
                        selectedMonth.next;
                  },
            icon: Icon(
              Icons.chevron_right_rounded,
              color: selectedMonth.isCurrentMonth
                  ? AppColors.textDisabled(context)
                  : AppColors.textPrimary(context),
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
        ],
      ),
    );
  }

  /// 월간 요약 카드 4개
  Widget _buildMonthlySummary(
    BuildContext context,
    AsyncValue<dynamic> summaryAsync,
  ) {
    return summaryAsync.when(
      loading: () => const RecordsSummarySkeleton(),
      error: (_, __) => GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.6,
        children: const [
          StatCard(label: '총 거리', value: '-', unit: 'km'),
          StatCard(label: '총 시간', value: '-', unit: ''),
          StatCard(label: '평균 페이스', value: '-', unit: '/km'),
          StatCard(label: '운동 횟수', value: '-', unit: '회'),
        ],
      ),
      data: (summary) {
        if (summary == null) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 1.6,
            children: const [
              StatCard(label: '총 거리', value: '0', unit: 'km'),
              StatCard(label: '총 시간', value: '0:00', unit: ''),
              StatCard(label: '평균 페이스', value: '-', unit: '/km'),
              StatCard(label: '운동 횟수', value: '0', unit: '회'),
            ],
          );
        }

        final distanceStr = summary.totalDistanceKm.toStringAsFixed(1);
        final timeStr = TimeFormatter.toReadable(summary.totalDurationSeconds);
        final paceStr = summary.avgPaceSecondsPerKm != null
            ? PaceFormatter.toMMSS(summary.avgPaceSecondsPerKm!)
            : '-';

        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: 1.6,
          children: [
            StatCard(
              label: '총 거리',
              value: distanceStr,
              unit: 'km',
            ),
            StatCard(
              label: '총 시간',
              value: timeStr,
            ),
            StatCard(
              label: '평균 페이스',
              value: paceStr,
              unit: '/km',
            ),
            StatCard(
              label: '운동 횟수',
              value: '${summary.totalWorkouts}',
              unit: '회',
            ),
          ],
        );
      },
    );
  }

  /// 기록 없을 때 빈 상태
  Widget _buildEmptyRecords(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_run_rounded,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '아직 운동 기록이 없습니다',
            style: AppTypography.h3.copyWith(
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'HealthKit 연동 후 자동으로 기록됩니다',
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Strava를 연동하면 더 풍부한 데이터를 확인할 수 있어요',
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 기록 리스트
  Widget _buildRecordsList(
    BuildContext context,
    AsyncValue<List<WorkoutLog>> recordsAsync,
  ) {
    return recordsAsync.when(
      loading: () => const RecordsListSkeleton(),
      error: (_, __) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          '기록을 불러오는데 실패했습니다',
          style: AppTypography.body.copyWith(color: AppColors.error),
        ),
      ),
      data: (records) {
        if (records.isEmpty) return _buildEmptyRecords(context);

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: records.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final record = records[index];
            return _buildRecordItem(context, record);
          },
        );
      },
    );
  }

  /// 개별 운동 기록 아이템
  Widget _buildRecordItem(BuildContext context, WorkoutLog record) {
    final date = record.workoutDate;
    final dateStr =
        '${date.month}/${date.day}(${_weekdayShort(date.weekday)})';
    final paceStr = record.avgPaceSecondsPerKm != null
        ? PaceFormatter.toMMSS(record.avgPaceSecondsPerKm!)
        : '-';
    final durationStr = TimeFormatter.toReadable(record.durationSeconds);

    // session_id로부터 훈련 유형 결정 (session 연결이 있으면 해당 유형, 없으면 기본)
    final zone = _getTrainingZoneFromSource(record);

    return GestureDetector(
      onTap: () {
        context.push('/records/${record.id}');
      },
      child: Container(
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
                Text(
                  dateStr,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                TrainingTypeBadge(zone: zone),
                const Spacer(),
                // 데이터 소스 아이콘
                _buildSourceIcon(record.source),
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${record.distanceKm.toStringAsFixed(1)}km  $durationStr  $paceStr/km',
              style: AppTypography.body.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            if (record.avgHeartRate != null) ...[
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
                    '${record.avgHeartRate}bpm',
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
    );
  }

  /// 데이터 소스 아이콘
  Widget _buildSourceIcon(String source) {
    if (source == 'strava') {
      return const Text(
        '\u{1F536}',
        style: AppTypography.bodySmall,
      );
    }
    return const Icon(
      Icons.favorite,
      color: AppColors.error,
      size: 14,
    );
  }

  /// WorkoutLog에서 TrainingZone 추정
  TrainingZone _getTrainingZoneFromSource(WorkoutLog log) {
    // 페이스 기반으로 훈련 유형 추정 (간단한 휴리스틱)
    final pace = log.avgPaceSecondsPerKm;
    if (pace == null) return TrainingZones.easy;

    // 매우 빠른 페이스 (< 4:30/km = 270초) -> 인터벌
    if (pace < 270) return TrainingZones.interval;
    // 빠른 페이스 (4:30~5:00 = 270~300초) -> 템포런
    if (pace < 300) return TrainingZones.threshold;
    // 중간 페이스 (5:00~5:30 = 300~330초) -> 마라톤페이스
    if (pace < 330) return TrainingZones.marathon;
    // 장거리 (distance > 15km, moderate pace) -> 장거리런
    if (log.distanceKm >= 15) return TrainingZones.longRun;
    // 기본 -> 이지런
    return TrainingZones.easy;
  }

  String _weekdayShort(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}
