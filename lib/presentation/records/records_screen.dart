import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../common/widgets/stat_card.dart';
import 'providers/records_provider.dart';

/// C-3 기록 화면 (운동 기록)
/// Phase 4에서 HealthKit/Strava 연동 후 실제 데이터 표시
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRecords = ref.watch(hasRecordsProvider);
    final summaryAsync = ref.watch(monthlySummaryProvider);
    final recordsAsync = ref.watch(workoutRecordsProvider);

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

              // 월간 요약 카드
              Text(
                '이번 달 요약',
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
    );
  }

  /// 월간 요약 카드 4개
  Widget _buildMonthlySummary(
    BuildContext context,
    AsyncValue<MonthlySummary?> summaryAsync,
  ) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.sm,
      crossAxisSpacing: AppSpacing.sm,
      childAspectRatio: 1.6,
      children: const [
        StatCard(
          label: '총 거리',
          value: '-',
          unit: 'km',
        ),
        StatCard(
          label: '총 시간',
          value: '-',
          unit: '',
        ),
        StatCard(
          label: '평균 페이스',
          value: '-',
          unit: '/km',
        ),
        StatCard(
          label: '운동 횟수',
          value: '-',
          unit: '회',
        ),
      ],
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
            color: AppColors.textSecondary.withOpacity(0.3),
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

  /// 기록 리스트 (Phase 4 이후 사용)
  Widget _buildRecordsList(
    BuildContext context,
    AsyncValue<List<WorkoutRecord>> recordsAsync,
  ) {
    return recordsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => Text(
        '기록을 불러오는데 실패했습니다',
        style: AppTypography.body.copyWith(color: AppColors.error),
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
  Widget _buildRecordItem(BuildContext context, WorkoutRecord record) {
    final date = record.date;
    final dateStr =
        '${date.month}/${date.day}(${_weekdayShort(date.weekday)})';
    final paceMin = record.paceSeconds ~/ 60;
    final paceSec = record.paceSeconds % 60;
    final paceStr = '$paceMin:${paceSec.toString().padLeft(2, '0')}';
    final durationMin = record.durationSeconds ~/ 60;
    final durationSec = record.durationSeconds % 60;
    final durationStr = '$durationMin:${durationSec.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        // TODO: D-2 운동 기록 상세로 이동
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$dateStr ${record.trainingType}',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Icon(
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
                color: AppColors.textSecondary,
              ),
            ),
            if (record.heartRate != null) ...[
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
                    '${record.heartRate}bpm',
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

  String _weekdayShort(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}
