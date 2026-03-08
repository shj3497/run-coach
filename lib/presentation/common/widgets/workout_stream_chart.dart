import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/training_zones.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pace_formatter.dart';

/// 스트림 메트릭 종류
enum StreamMetricType {
  heartRate,
  altitude,
  pace,
}

/// (거리km, 값) 쌍
class _DataPoint {
  final double distKm;
  final double value;
  const _DataPoint(this.distKm, this.value);
}

/// 운동 스트림 그래프 위젯
///
/// CupertinoSlidingSegmentedControl로 심박수/고도/페이스 그래프를 전환합니다.
/// X축은 거리(km), 터치로 해당 지점의 값을 확인할 수 있습니다.
class WorkoutStreamChart extends StatefulWidget {
  final List<dynamic> streamData;

  const WorkoutStreamChart({super.key, required this.streamData});

  @override
  State<WorkoutStreamChart> createState() => _WorkoutStreamChartState();
}

class _WorkoutStreamChartState extends State<WorkoutStreamChart> {
  late List<StreamMetricType> _availableMetrics;
  late StreamMetricType _selected;

  // 파싱된 (거리km, 값) 데이터 캐시
  List<_DataPoint>? _hrData;
  List<_DataPoint>? _altData;
  List<_DataPoint>? _paceData;
  double _maxDistKm = 0;

  @override
  void initState() {
    super.initState();
    _parseStreamData();
  }

  @override
  void didUpdateWidget(covariant WorkoutStreamChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.streamData != widget.streamData) {
      _parseStreamData();
    }
  }

  void _parseStreamData() {
    final hrPoints = <_DataPoint>[];
    final altPoints = <_DataPoint>[];
    final pacePoints = <_DataPoint>[];
    var hasDistance = false;

    for (final item in widget.streamData) {
      if (item is! Map<String, dynamic>) continue;

      final distM = item['distance_m'] as num?;
      if (distM == null) continue; // distance 없으면 건너뜀
      hasDistance = true;
      final distKm = distM.toDouble() / 1000.0;

      final bpm = item['bpm'] as num?;
      if (bpm != null && bpm > 0) {
        hrPoints.add(_DataPoint(distKm, bpm.toDouble()));
      }

      final alt = item['altitude_m'] as num?;
      if (alt != null) {
        altPoints.add(_DataPoint(distKm, alt.toDouble()));
      }

      final vel = item['velocity_mps'] as num?;
      if (vel != null && vel > 0.1) {
        pacePoints.add(_DataPoint(distKm, 1000.0 / vel.toDouble()));
      }
    }

    // distance 스트림이 없는 구 데이터 → 인덱스 기반 폴백
    if (!hasDistance) {
      _parseStreamDataLegacy();
      return;
    }

    // 페이스: 이상치 클램핑 → 이동 평균 스무딩 → 다운샘플링
    final clampedPace = _clampPaceOutliers(pacePoints);
    final smoothedPace = _smoothMovingAverage(clampedPace, 20);

    _hrData = hrPoints.length >= 2 ? _downsample(hrPoints, 200) : null;
    _altData = altPoints.length >= 2 ? _downsample(altPoints, 200) : null;
    _paceData = smoothedPace.length >= 2
        ? _downsample(smoothedPace, 200)
        : null;

    _maxDistKm = 0;
    if (_hrData != null && _hrData!.last.distKm > _maxDistKm) {
      _maxDistKm = _hrData!.last.distKm;
    }
    if (_altData != null && _altData!.last.distKm > _maxDistKm) {
      _maxDistKm = _altData!.last.distKm;
    }
    if (_paceData != null && _paceData!.last.distKm > _maxDistKm) {
      _maxDistKm = _paceData!.last.distKm;
    }

    _availableMetrics = [];
    if (_hrData != null) _availableMetrics.add(StreamMetricType.heartRate);
    if (_altData != null) _availableMetrics.add(StreamMetricType.altitude);
    if (_paceData != null) _availableMetrics.add(StreamMetricType.pace);

    _selected = _availableMetrics.isNotEmpty
        ? _availableMetrics.first
        : StreamMetricType.heartRate;
  }

  /// distance_m 없는 구 데이터용 폴백 파싱
  void _parseStreamDataLegacy() {
    final hrValues = <double>[];
    final altValues = <double>[];
    final paceValues = <double>[];

    for (final item in widget.streamData) {
      if (item is! Map<String, dynamic>) continue;
      final bpm = item['bpm'] as num?;
      if (bpm != null && bpm > 0) hrValues.add(bpm.toDouble());
      final alt = item['altitude_m'] as num?;
      if (alt != null) altValues.add(alt.toDouble());
      final vel = item['velocity_mps'] as num?;
      if (vel != null && vel > 0.1) paceValues.add(1000.0 / vel.toDouble());
    }

    // 인덱스 기반 → 임의 거리 매핑 (0~N)
    List<_DataPoint> toPoints(List<double> vals) {
      final pts = <_DataPoint>[];
      for (var i = 0; i < vals.length; i++) {
        pts.add(_DataPoint(i.toDouble(), vals[i]));
      }
      return pts;
    }

    _hrData = hrValues.length >= 2
        ? _downsample(toPoints(hrValues), 200)
        : null;
    _altData = altValues.length >= 2
        ? _downsample(toPoints(altValues), 200)
        : null;
    final clampedPacePts = _clampPaceOutliers(toPoints(paceValues));
    final smoothedPacePts = _smoothMovingAverage(clampedPacePts, 20);
    _paceData = smoothedPacePts.length >= 2
        ? _downsample(smoothedPacePts, 200)
        : null;

    _maxDistKm = 0;

    _availableMetrics = [];
    if (_hrData != null) _availableMetrics.add(StreamMetricType.heartRate);
    if (_altData != null) _availableMetrics.add(StreamMetricType.altitude);
    if (_paceData != null) _availableMetrics.add(StreamMetricType.pace);

    _selected = _availableMetrics.isNotEmpty
        ? _availableMetrics.first
        : StreamMetricType.heartRate;
  }

  @override
  Widget build(BuildContext context) {
    if (_availableMetrics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 세그먼트 컨트롤 (2개 이상일 때만)
        if (_availableMetrics.length > 1) ...[
          SizedBox(
            width: double.infinity,
            child: CupertinoSlidingSegmentedControl<StreamMetricType>(
              groupValue: _selected,
              backgroundColor: AppColors.background(context),
              thumbColor: AppColors.surface(context),
              children: {
                for (final metric in _availableMetrics)
                  metric: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: Text(
                      _metricLabel(metric),
                      style: AppTypography.bodySmall.copyWith(
                        color: _selected == metric
                            ? AppColors.textPrimary(context)
                            : AppColors.textSecondary,
                        fontWeight: _selected == metric
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                    ),
                  ),
              },
              onValueChanged: (value) {
                if (value != null) setState(() => _selected = value);
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
        ],

        // 요약 행
        _buildSummaryRow(context),
        const SizedBox(height: AppSpacing.md),

        // fl_chart 라인 차트
        SizedBox(
          height: 150,
          child: _buildLineChart(context),
        ),
      ],
    );
  }

  Widget _buildLineChart(BuildContext context) {
    final data = _currentData;
    if (data.isEmpty) return const SizedBox.shrink();

    final color = _lineColor(context);
    final invertY = _selected == StreamMetricType.pace;
    final hasDistanceAxis = _maxDistKm > 0;

    final values = data.map((p) => p.value).toList();
    final minVal = values.reduce(math.min);
    final maxVal = values.reduce(math.max);
    final range = maxVal - minVal;
    final yPadding = range > 0 ? range * 0.08 : 1.0;

    final spots = <FlSpot>[];
    for (final pt in data) {
      final y = invertY ? -pt.value : pt.value;
      spots.add(FlSpot(pt.distKm, y));
    }

    final chartMinY = invertY ? -(maxVal + yPadding) : minVal - yPadding;
    final chartMaxY = invertY ? -(minVal - yPadding) : maxVal + yPadding;

    // X축 라벨 간격 계산 (정수 km 단위)
    final xMax = data.last.distKm;
    final kmInterval = _calcKmInterval(xMax);

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false)),
          bottomTitles: hasDistanceAxis
              ? AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: kmInterval,
                    reservedSize: 20,
                    getTitlesWidget: (value, meta) {
                      // 첫/끝 라벨과 겹치면 숨김
                      if (value <= 0 || value >= xMax - kmInterval * 0.3) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        '${value.toInt()}km',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      );
                    },
                  ),
                )
              : const AxisTitles(
                  sideTitles: SideTitles(showTitles: false)),
        ),
        minX: 0,
        maxX: xMax,
        minY: chartMinY,
        maxY: chartMaxY,
        clipData: const FlClipData.all(),
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) =>
                AppColors.surfaceElevated(context).withValues(alpha: 0.95),
            tooltipRoundedRadius: 8,
            tooltipPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final displayValue = invertY ? -spot.y : spot.y;
                final kmText = hasDistanceAxis
                    ? '${spot.x.toStringAsFixed(1)}km  '
                    : '';
                return LineTooltipItem(
                  '$kmText${_formatValue(displayValue)}',
                  AppTypography.bodySmall.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                );
              }).toList();
            },
          ),
          touchCallback: (event, response) {
            if (event is FlLongPressStart) {
              HapticFeedback.mediumImpact();
            }
          },
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: color.withValues(alpha: 0.4),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, bar, index) {
                    return FlDotCirclePainter(
                      radius: 5,
                      color: color,
                      strokeWidth: 2,
                      strokeColor: AppColors.surfaceElevated(context),
                    );
                  },
                ),
              );
            }).toList();
          },
          handleBuiltInTouches: true,
          touchSpotThreshold: 24,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            preventCurveOverShooting: true,
            color: color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            if (_currentAvg != null)
              HorizontalLine(
                y: invertY ? -_currentAvg! : _currentAvg!,
                color: AppColors.textSecondary.withValues(alpha: 0.4),
                strokeWidth: 1,
                dashArray: [6, 4],
              ),
          ],
        ),
      ),
      duration: const Duration(milliseconds: 200),
    );
  }

  /// 터치 시 표시할 값 포맷
  String _formatValue(double value) {
    switch (_selected) {
      case StreamMetricType.heartRate:
        return '${value.round()}bpm';
      case StreamMetricType.altitude:
        return '${value.toStringAsFixed(1)}m';
      case StreamMetricType.pace:
        final paceSeconds = value.round();
        return '${PaceFormatter.toMMSS(paceSeconds)}/km';
    }
  }

  Widget _buildSummaryRow(BuildContext context) {
    final data = _currentData;
    if (data.isEmpty) return const SizedBox.shrink();

    final values = data.map((p) => p.value).toList();
    String leftLabel;
    String rightLabel;

    switch (_selected) {
      case StreamMetricType.heartRate:
        final avg = _currentAvg?.round() ?? '-';
        final max = values.reduce(math.max).round();
        leftLabel = '평균 ${avg}bpm';
        rightLabel = '최대 ${max}bpm';
      case StreamMetricType.altitude:
        final min = values.reduce(math.min);
        final max = values.reduce(math.max);
        leftLabel = '최저 ${min.toStringAsFixed(0)}m';
        rightLabel = '최고 ${max.toStringAsFixed(0)}m';
      case StreamMetricType.pace:
        final avg = _currentAvg;
        final fastest = values.reduce(math.min);
        leftLabel =
            '평균 ${avg != null ? PaceFormatter.toMMSS(avg.round()) : "-"}/km';
        rightLabel = '최고 ${PaceFormatter.toMMSS(fastest.round())}/km';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          leftLabel,
          style: AppTypography.bodySmall
              .copyWith(color: AppColors.textSecondary),
        ),
        Text(
          rightLabel,
          style: AppTypography.bodySmall
              .copyWith(color: _lineColor(context)),
        ),
      ],
    );
  }

  List<_DataPoint> get _currentData {
    switch (_selected) {
      case StreamMetricType.heartRate:
        return _hrData ?? [];
      case StreamMetricType.altitude:
        return _altData ?? [];
      case StreamMetricType.pace:
        return _paceData ?? [];
    }
  }

  double? get _currentAvg {
    final data = _currentData;
    if (data.isEmpty) return null;
    final sum = data.fold(0.0, (s, p) => s + p.value);
    return sum / data.length;
  }

  Color _lineColor(BuildContext context) {
    switch (_selected) {
      case StreamMetricType.heartRate:
        return AppColors.error;
      case StreamMetricType.altitude:
        return TrainingZones.easyColor;
      case StreamMetricType.pace:
        return AppColors.primary(context);
    }
  }

  String _metricLabel(StreamMetricType metric) {
    switch (metric) {
      case StreamMetricType.heartRate:
        return '심박수';
      case StreamMetricType.altitude:
        return '고도';
      case StreamMetricType.pace:
        return '페이스';
    }
  }

  /// 페이스 이상치 클램핑 (IQR 기반)
  ///
  /// GPS 글리치, 신호 대기 등으로 인한 비정상적 페이스를
  /// Q3 + 1.5 × IQR 상한으로 클램핑합니다.
  static List<_DataPoint> _clampPaceOutliers(List<_DataPoint> data) {
    if (data.length < 4) return data;

    final sorted = data.map((p) => p.value).toList()..sort();
    final q1 = sorted[(sorted.length * 0.25).floor()];
    final q3 = sorted[(sorted.length * 0.75).floor()];
    final iqr = q3 - q1;
    final upperBound = q3 + 1.5 * iqr;

    return data
        .map((p) => _DataPoint(
              p.distKm,
              p.value > upperBound ? upperBound : p.value,
            ))
        .toList();
  }

  /// 이동 평균 스무딩
  ///
  /// [windowSize]개 포인트의 평균으로 노이즈를 제거합니다.
  /// 거리(distKm)는 윈도우 중앙값을 사용합니다.
  static List<_DataPoint> _smoothMovingAverage(
      List<_DataPoint> data, int windowSize) {
    if (data.length <= windowSize) return data;

    final half = windowSize ~/ 2;
    final result = <_DataPoint>[];

    for (var i = 0; i < data.length; i++) {
      final start = (i - half).clamp(0, data.length - 1);
      final end = (i + half + 1).clamp(0, data.length);
      var sum = 0.0;
      for (var j = start; j < end; j++) {
        sum += data[j].value;
      }
      result.add(_DataPoint(data[i].distKm, sum / (end - start)));
    }

    return result;
  }

  /// X축 km 라벨 간격 계산
  double _calcKmInterval(double maxKm) {
    if (maxKm <= 3) return 1;
    if (maxKm <= 8) return 2;
    if (maxKm <= 20) return 5;
    return 10;
  }

  /// LTTB (Largest Triangle Three Buckets) 다운샘플링 — 2D 버전
  static List<_DataPoint> _downsample(
      List<_DataPoint> data, int threshold) {
    if (data.length <= threshold) return data;

    final sampled = <_DataPoint>[data.first];
    final bucketSize = (data.length - 2) / (threshold - 2);

    var prevIndex = 0;

    for (var i = 0; i < threshold - 2; i++) {
      final avgRangeStart = ((i + 1) * bucketSize).floor() + 1;
      final avgRangeEnd =
          (((i + 2) * bucketSize).floor() + 1).clamp(0, data.length);

      var avgX = 0.0;
      var avgY = 0.0;
      final avgRangeLength = avgRangeEnd - avgRangeStart;
      if (avgRangeLength > 0) {
        for (var j = avgRangeStart; j < avgRangeEnd; j++) {
          avgX += data[j].distKm;
          avgY += data[j].value;
        }
        avgX /= avgRangeLength;
        avgY /= avgRangeLength;
      }

      final rangeStart = (i * bucketSize).floor() + 1;
      final rangeEnd = avgRangeStart;

      var maxArea = -1.0;
      var maxAreaIndex = rangeStart;

      final prevX = data[prevIndex].distKm;
      final prevY = data[prevIndex].value;

      for (var j = rangeStart; j < rangeEnd; j++) {
        final area = ((prevX - avgX) * (data[j].value - prevY) -
                    (prevX - data[j].distKm) * (avgY - prevY))
                .abs() *
            0.5;
        if (area > maxArea) {
          maxArea = area;
          maxAreaIndex = j;
        }
      }

      sampled.add(data[maxAreaIndex]);
      prevIndex = maxAreaIndex;
    }

    sampled.add(data.last);
    return sampled;
  }
}
