import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/pace_formatter.dart';
import '../../../data/services/weather_service.dart';
import '../../providers/coaching_providers.dart';

/// 날씨 기반 페이스 보정 카드
///
/// D-1 세션 상세 화면에서 현재 날씨와 페이스 보정을 표시합니다.
class WeatherAdjustmentCard extends StatelessWidget {
  final PaceAdjustmentResult result;
  final String? originalPace;

  const WeatherAdjustmentCard({
    super.key,
    required this.result,
    this.originalPace,
  });

  @override
  Widget build(BuildContext context) {
    final weather = result.weather;
    final emoji = WeatherService.getWeatherEmoji(weather.iconCode);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 보정 필요 없음
    if (!result.needsAdjustment) {
      return _buildOptimalCard(context, weather, emoji, isDark);
    }

    // 보정 필요
    return _buildAdjustmentCard(context, weather, emoji, isDark);
  }

  /// 최적 날씨 (보정 불필요)
  Widget _buildOptimalCard(
    BuildContext context,
    WeatherData weather,
    String emoji,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.success.withValues(alpha: 0.12)
            : AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${weather.temperatureC.toStringAsFixed(0)}°C ${weather.conditionDetail}',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  result.summary,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 보정 필요 카드
  Widget _buildAdjustmentCard(
    BuildContext context,
    WeatherData weather,
    String emoji,
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.warning.withValues(alpha: 0.12)
            : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더: 날씨 + 온도
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${weather.temperatureC.toStringAsFixed(0)}°C ${weather.conditionDetail}',
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
                ),
                child: Text(
                  '+${result.adjustmentPercent.toStringAsFixed(0)}%',
                  style: AppTypography.bodySmall.copyWith(
                    color: isDark ? AppColors.warning : const Color(0xFFC2410C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // 페이스 보정 결과
          if (originalPace != null && result.adjustedPaceRange != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.speed_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  originalPace!,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  result.adjustedPaceRange!,
                  style: AppTypography.body.copyWith(
                    color: isDark ? AppColors.warning : const Color(0xFFC2410C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // 요약 메시지
          Text(
            result.summary,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// 저장된 날씨 보정 이력 카드 (완료된 세션용)
///
/// workout_log.weatherContext에서 읽어온 과거 보정 데이터를 표시합니다.
class WeatherHistoryCard extends StatelessWidget {
  final Map<String, dynamic> weatherContext;
  final int? actualPaceSecondsPerKm;

  const WeatherHistoryCard({
    super.key,
    required this.weatherContext,
    this.actualPaceSecondsPerKm,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tempC = (weatherContext['temperature_c'] as num?)?.toDouble();
    final condition = weatherContext['condition'] as String? ?? '';
    final adjustmentPercent =
        (weatherContext['adjustment_percent'] as num?)?.toDouble() ?? 0;
    final originalPace = weatherContext['original_pace'] as String?;
    final adjustedPace = weatherContext['adjusted_pace'] as String?;

    final hasAdjustment = adjustmentPercent > 0;

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
          // 헤더
          Row(
            children: [
              const Icon(
                Icons.thermostat_rounded,
                size: 20,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '훈련 당일 날씨',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const Spacer(),
              if (tempC != null)
                Text(
                  '${tempC.toStringAsFixed(0)}°C $condition',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),

          if (hasAdjustment && originalPace != null) ...[
            const SizedBox(height: AppSpacing.md),

            // 3단계 페이스 비교: 원래 → 보정 → 실제
            _buildPaceRow(
              context,
              label: '목표 페이스',
              value: originalPace,
              color: AppColors.textSecondary,
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.sm),
            _buildPaceRow(
              context,
              label: '날씨 보정',
              value: adjustedPace ?? originalPace,
              color: isDark ? AppColors.warning : const Color(0xFFC2410C),
              isDark: isDark,
              badge: '+${adjustmentPercent.toStringAsFixed(0)}%',
            ),
            if (actualPaceSecondsPerKm != null) ...[
              const SizedBox(height: AppSpacing.sm),
              _buildPaceRow(
                context,
                label: '실제 페이스',
                value: PaceFormatter.toDisplay(actualPaceSecondsPerKm!),
                color: AppColors.primary(context),
                isDark: isDark,
                isActual: true,
              ),
            ],
          ] else if (!hasAdjustment) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              '러닝에 최적인 날씨였습니다',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaceRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    String? badge,
    bool isActual = false,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Text(
          value,
          style: AppTypography.body.copyWith(
            color: color,
            fontWeight: isActual ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
        if (badge != null) ...[
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
            ),
            child: Text(
              badge,
              style: AppTypography.caption.copyWith(
                color: isDark ? AppColors.warning : const Color(0xFFC2410C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// 미래 세션용 날씨 안내 카드
class WeatherFutureCard extends StatelessWidget {
  const WeatherFutureCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
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
              '훈련 당일에 날씨 기반 페이스 보정이 제공됩니다',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
