import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/training_zones.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/pace_formatter.dart';
import '../../core/utils/time_formatter.dart';
import '../../data/models/workout_log.dart';
import '../common/widgets/km_split_bar.dart';
import '../common/widgets/stat_card.dart';
import '../providers/data_providers.dart';

/// D-2 운동 기록 상세 화면
class WorkoutDetailScreen extends ConsumerWidget {
  final String workoutId;

  const WorkoutDetailScreen({super.key, required this.workoutId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workoutAsync = ref.watch(workoutLogProvider(workoutId));

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_rounded,
            color: AppColors.textPrimary(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          '운동 기록',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
      ),
      body: workoutAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                '기록을 불러올 수 없습니다',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        data: (workout) {
          if (workout == null) {
            return Center(
              child: Text(
                '기록을 찾을 수 없습니다',
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            );
          }
          return _buildContent(context, ref, workout);
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    WidgetRef ref,
    WorkoutLog workout,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpacing.lg),

          // 날짜 + 훈련 유형 헤더
          _buildHeader(context, workout),
          const SizedBox(height: AppSpacing.lg),

          // 운동 요약 카드
          _buildSummaryCard(context, workout),
          const SizedBox(height: AppSpacing.xl),

          // 구간별 페이스
          if (workout.splits != null && workout.splits!.isNotEmpty) ...[
            _buildSplitsSection(context, workout),
            const SizedBox(height: AppSpacing.xl),
          ],

          // 심박수 그래프
          if (workout.heartRateData != null &&
              workout.heartRateData!.isNotEmpty) ...[
            _buildHeartRateSection(context, workout),
            const SizedBox(height: AppSpacing.xl),
          ],

          // 추가 정보 (날씨, 고도)
          if (_hasAdditionalInfo(workout)) ...[
            _buildAdditionalInfo(context, workout),
            const SizedBox(height: AppSpacing.xl),
          ],

          // 피드백 메시지
          if (workout.sessionId != null)
            _buildFeedbackSection(context, ref, workout),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  /// 헤더: 날짜 + 훈련유형 + 데이터소스
  Widget _buildHeader(BuildContext context, WorkoutLog workout) {
    final date = workout.workoutDate;
    final dateStr =
        '${date.month}/${date.day}(${_weekdayShort(date.weekday)})';
    final zone = _estimateTrainingZone(workout);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$dateStr ${zone.shortLabel}',
          style: AppTypography.h1.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Text(
              'via ',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            if (workout.source == 'strava') ...[
              Text(
                'Strava ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Text('\u{1F536}', style: TextStyle(fontSize: 12)),
            ] else ...[
              Text(
                'HealthKit ',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Icon(
                Icons.favorite,
                color: AppColors.error,
                size: 14,
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// 운동 요약 카드
  Widget _buildSummaryCard(BuildContext context, WorkoutLog workout) {
    final paceStr = workout.avgPaceSecondsPerKm != null
        ? PaceFormatter.toMMSS(workout.avgPaceSecondsPerKm!)
        : '-';
    final durationStr = TimeFormatter.toReadable(workout.durationSeconds);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        children: [
          // 첫 번째 줄: 거리, 시간
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: '거리',
                  value: workout.distanceKm.toStringAsFixed(1),
                  unit: 'km',
                  useLargeStyle: true,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: StatCard(
                  label: '시간',
                  value: durationStr,
                  useLargeStyle: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // 두 번째 줄: 페이스, 심박수
          Row(
            children: [
              Expanded(
                child: StatCard(
                  label: '평균 페이스',
                  value: paceStr,
                  unit: '/km',
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
          // 세 번째 줄: 칼로리 (있으면)
          if (workout.totalCalories != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: StatCard(
                    label: '칼로리',
                    value: '${workout.totalCalories}',
                    unit: 'kcal',
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: workout.maxHeartRate != null
                      ? StatCard(
                          label: '최대 심박수',
                          value: '${workout.maxHeartRate}',
                          unit: 'bpm',
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 구간별 페이스 섹션
  Widget _buildSplitsSection(BuildContext context, WorkoutLog workout) {
    final splits = _parseSplits(workout.splits!);
    if (splits.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '구간별 페이스',
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: KmSplitChart(splits: splits),
        ),
      ],
    );
  }

  /// splits jsonb 파싱 -> KmSplitData 리스트
  List<KmSplitData> _parseSplits(List<dynamic> splits) {
    final result = <KmSplitData>[];
    for (final split in splits) {
      if (split is Map<String, dynamic>) {
        final km = split['km'] as int? ?? (result.length + 1);
        final paceSeconds = split['pace_seconds'] as int? ?? 0;
        if (paceSeconds <= 0) continue;

        final paceText = PaceFormatter.toMMSS(paceSeconds);
        final color = _getZoneColorForPace(paceSeconds);

        result.add(KmSplitData(
          km: km,
          paceSeconds: paceSeconds,
          paceText: paceText,
          color: color,
        ));
      }
    }
    return result;
  }

  /// 페이스에 따른 존 컬러 결정
  Color _getZoneColorForPace(int paceSeconds) {
    // 기본적인 페이스 기반 존 컬러 매핑
    if (paceSeconds < 270) return TrainingZones.repetitionColor; // < 4:30
    if (paceSeconds < 285) return TrainingZones.intervalColor;   // 4:30~4:45
    if (paceSeconds < 310) return TrainingZones.thresholdColor;  // 4:45~5:10
    if (paceSeconds < 340) return TrainingZones.marathonColor;   // 5:10~5:40
    return TrainingZones.easyColor;                               // >= 5:40
  }

  /// 심박수 그래프 섹션
  Widget _buildHeartRateSection(BuildContext context, WorkoutLog workout) {
    final hrData = _parseHeartRateData(workout.heartRateData!);
    if (hrData.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '심박수 추이',
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            children: [
              // 심박수 범위 표시
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '평균 ${workout.avgHeartRate ?? "-"}bpm',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '최대 ${workout.maxHeartRate ?? "-"}bpm',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              // CustomPaint 심박수 라인 차트
              SizedBox(
                height: 150,
                width: double.infinity,
                child: CustomPaint(
                  painter: HeartRateChartPainter(
                    data: hrData,
                    avgHeartRate: workout.avgHeartRate,
                    lineColor: AppColors.error,
                    avgLineColor: AppColors.textSecondary.withValues(alpha: 0.5),
                    fillColor: AppColors.error.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// heart_rate_data jsonb 파싱
  List<int> _parseHeartRateData(List<dynamic> data) {
    final result = <int>[];
    for (final item in data) {
      if (item is Map<String, dynamic>) {
        final bpm = item['bpm'] as int?;
        if (bpm != null && bpm > 0) {
          result.add(bpm);
        }
      } else if (item is int) {
        result.add(item);
      }
    }
    return result;
  }

  /// 추가 정보 존재 여부
  bool _hasAdditionalInfo(WorkoutLog workout) {
    return workout.weatherTempC != null ||
        workout.totalElevationGainM != null ||
        workout.avgCadence != null;
  }

  /// 추가 정보 섹션 (날씨, 고도, 케이던스)
  Widget _buildAdditionalInfo(BuildContext context, WorkoutLog workout) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '추가 정보',
          style: AppTypography.h2.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            children: [
              if (workout.weatherTempC != null)
                _buildInfoRow(
                  context,
                  Icons.thermostat_rounded,
                  '날씨',
                  '${workout.weatherTempC!.toStringAsFixed(0)}\u00B0C ${workout.weatherCondition ?? ""}',
                ),
              if (workout.totalElevationGainM != null) ...[
                if (workout.weatherTempC != null)
                  Divider(
                    color: AppColors.divider(context),
                    height: AppSpacing.lg * 2,
                  ),
                _buildInfoRow(
                  context,
                  Icons.terrain_rounded,
                  '고도 상승',
                  '${workout.totalElevationGainM!.toStringAsFixed(0)}m',
                ),
              ],
              if (workout.avgCadence != null) ...[
                Divider(
                  color: AppColors.divider(context),
                  height: AppSpacing.lg * 2,
                ),
                _buildInfoRow(
                  context,
                  Icons.speed_rounded,
                  '평균 케이던스',
                  '${workout.avgCadence} spm',
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// 정보 행
  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: AppColors.textSecondary,
        ),
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
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// 피드백 메시지 섹션
  Widget _buildFeedbackSection(
    BuildContext context,
    WidgetRef ref,
    WorkoutLog workout,
  ) {
    if (workout.sessionId == null) return const SizedBox.shrink();

    // coaching_repository에서 세션 피드백 조회
    final feedbackAsync = ref.watch(
      _sessionFeedbackProvider(workout.sessionId!),
    );

    return feedbackAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (feedback) {
        if (feedback == null || feedback.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '코치 피드백',
              style: AppTypography.h2.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary(context),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      feedback,
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        );
      },
    );
  }

  /// 훈련 존 추정 (간단한 휴리스틱)
  TrainingZone _estimateTrainingZone(WorkoutLog log) {
    final pace = log.avgPaceSecondsPerKm;
    if (pace == null) return TrainingZones.easy;

    if (pace < 270) return TrainingZones.interval;
    if (pace < 300) return TrainingZones.threshold;
    if (pace < 330) return TrainingZones.marathon;
    if (log.distanceKm >= 15) return TrainingZones.longRun;
    return TrainingZones.easy;
  }

  String _weekdayShort(int weekday) {
    const days = ['월', '화', '수', '목', '금', '토', '일'];
    return days[weekday - 1];
  }
}

/// 세션 피드백 Provider
final _sessionFeedbackProvider =
    FutureProvider.family<String?, String>((ref, sessionId) async {
  final coachingRepo = ref.watch(coachingRepositoryProvider);
  final feedback = await coachingRepo.getSessionFeedback(sessionId);
  return feedback?.content;
});

/// 심박수 라인 차트 CustomPainter
class HeartRateChartPainter extends CustomPainter {
  final List<int> data;
  final int? avgHeartRate;
  final Color lineColor;
  final Color avgLineColor;
  final Color fillColor;

  HeartRateChartPainter({
    required this.data,
    this.avgHeartRate,
    required this.lineColor,
    required this.avgLineColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final minBpm = data.reduce((a, b) => a < b ? a : b).toDouble();
    final maxBpm = data.reduce((a, b) => a > b ? a : b).toDouble();
    final range = maxBpm - minBpm;
    final effectiveRange = range > 0 ? range : 1.0;

    // 패딩
    const topPadding = 8.0;
    const bottomPadding = 8.0;
    final chartHeight = size.height - topPadding - bottomPadding;

    // 데이터 포인트 간격
    final stepX = size.width / (data.length - 1).clamp(1, data.length);

    // 라인 패스 생성
    final linePath = Path();
    final fillPath = Path();

    for (var i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = (data[i] - minBpm) / effectiveRange;
      final y = topPadding + chartHeight * (1 - normalizedY);

      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        linePath.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // Fill path 닫기
    fillPath.lineTo((data.length - 1) * stepX, size.height);
    fillPath.close();

    // Fill 그리기
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(fillPath, fillPaint);

    // Line 그리기
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(linePath, linePaint);

    // 평균 심박수 점선
    if (avgHeartRate != null && range > 0) {
      final normalizedAvg = (avgHeartRate! - minBpm) / effectiveRange;
      final avgY = topPadding + chartHeight * (1 - normalizedAvg);

      final dashPaint = Paint()
        ..color = avgLineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      // 점선 그리기
      const dashWidth = 6.0;
      const dashSpace = 4.0;
      var startX = 0.0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, avgY),
          Offset((startX + dashWidth).clamp(0, size.width), avgY),
          dashPaint,
        );
        startX += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant HeartRateChartPainter oldDelegate) {
    return oldDelegate.data != data ||
        oldDelegate.avgHeartRate != avgHeartRate;
  }
}
