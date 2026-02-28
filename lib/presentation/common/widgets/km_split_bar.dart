import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 구간별 페이스 바 (개별 항목)
class KmSplitBar extends StatelessWidget {
  final int km;
  final String paceText;
  final double relativeValue; // 0.0 ~ 1.0 (최대 페이스 대비 비율)
  final Color color;

  const KmSplitBar({
    super.key,
    required this.km,
    required this.paceText,
    required this.relativeValue,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          // km 번호
          SizedBox(
            width: 36,
            child: Text(
              '${km}km',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 수평 바
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SizedBox(
                height: 24,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: relativeValue.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          // 페이스 텍스트
          SizedBox(
            width: 48,
            child: Text(
              paceText,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textPrimary(context),
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// 구간별 페이스 바 차트 (목록)
class KmSplitChart extends StatelessWidget {
  final List<KmSplitData> splits;

  const KmSplitChart({super.key, required this.splits});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();

    // 최대 페이스 값 기준으로 상대값 계산
    final maxPaceSeconds = splits
        .map((s) => s.paceSeconds)
        .reduce((a, b) => a > b ? a : b);

    return Column(
      children: splits.asMap().entries.map((entry) {
        final split = entry.value;
        return KmSplitBar(
          km: split.km,
          paceText: split.paceText,
          relativeValue: split.paceSeconds / maxPaceSeconds,
          color: split.color,
        );
      }).toList(),
    );
  }
}

/// 구간 데이터
class KmSplitData {
  final int km;
  final int paceSeconds; // 초/km
  final String paceText; // "5:48" 형식
  final Color color;     // 존 컬러

  const KmSplitData({
    required this.km,
    required this.paceSeconds,
    required this.paceText,
    required this.color,
  });
}
