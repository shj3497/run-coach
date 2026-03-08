import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 구간 데이터
class KmSplitData {
  final int km;
  final int paceSeconds; // 초/km
  final String paceText; // "5:48" 형식
  final Color color;     // 존 컬러
  final int? avgHeartRate;    // 구간 평균 심박수
  final double? elevationDiffM; // 구간 고도 변화 (m)

  const KmSplitData({
    required this.km,
    required this.paceSeconds,
    required this.paceText,
    required this.color,
    this.avgHeartRate,
    this.elevationDiffM,
  });
}

/// NRC 스타일 구간별 스플릿 테이블
class KmSplitTable extends StatelessWidget {
  final List<KmSplitData> splits;

  const KmSplitTable({super.key, required this.splits});

  @override
  Widget build(BuildContext context) {
    if (splits.isEmpty) return const SizedBox.shrink();

    final hasAnyHr = splits.any((s) => s.avgHeartRate != null);
    final hasAnyElev = splits.any((s) => s.elevationDiffM != null);

    return Column(
      children: [
        // 헤더 행
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  'km',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
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
              if (hasAnyHr)
                Expanded(
                  child: Text(
                    '심박',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              if (hasAnyElev)
                Expanded(
                  child: Text(
                    '고도',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
            ],
          ),
        ),
        Divider(color: AppColors.divider(context), height: 1),
        // 데이터 행
        ...splits.asMap().entries.map((entry) {
          final index = entry.key;
          final split = entry.value;

          return Column(
            children: [
              if (index > 0)
                Divider(color: AppColors.divider(context), height: 1),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    // km 번호
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${split.km}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    // 페이스 (존 컬러 dot + 값)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: split.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${split.paceText}/km',
                            style: AppTypography.body.copyWith(
                              color: AppColors.textPrimary(context),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 심박수
                    if (hasAnyHr)
                      Expanded(
                        child: Text(
                          split.avgHeartRate != null
                              ? '${split.avgHeartRate}bpm'
                              : '-',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary(context),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    // 고도
                    if (hasAnyElev)
                      Expanded(
                        child: Text(
                          _formatElevation(split.elevationDiffM),
                          style: AppTypography.body.copyWith(
                            color: _elevationColor(context, split.elevationDiffM),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }

  String _formatElevation(double? elev) {
    if (elev == null) return '-';
    final rounded = elev.round();
    if (rounded >= 0) return '\u25B2 +${rounded}m';
    return '\u25BC ${rounded}m';
  }

  Color _elevationColor(BuildContext context, double? elev) {
    if (elev == null) return AppColors.textSecondary;
    if (elev >= 0) return AppColors.textPrimary(context);
    return AppColors.textSecondary;
  }
}
