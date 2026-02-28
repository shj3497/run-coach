import 'package:flutter/material.dart';
import '../../../core/constants/training_zones.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';
import 'training_type_badge.dart';

/// 훈련 세션 상태
enum SessionStatus {
  completed,  // ✅ 완료
  pending,    // 🔲 예정
  missed,     // ⚠️ 미완료 (skipped와 동의어)
  skipped,    // ⚠️ 건너뜀 (DB에서 사용)
  partial,    // ◑ 일부 완료
  rest,       // ─ 휴식
}

/// DB status 문자열 → SessionStatus 변환
SessionStatus sessionStatusFromDbString(String dbValue) {
  switch (dbValue) {
    case 'completed':
      return SessionStatus.completed;
    case 'pending':
      return SessionStatus.pending;
    case 'skipped':
      return SessionStatus.skipped;
    case 'partial':
      return SessionStatus.partial;
    default:
      return SessionStatus.pending;
  }
}

/// SessionStatus → DB status 문자열 변환
String sessionStatusToDbString(SessionStatus status) {
  switch (status) {
    case SessionStatus.completed:
      return 'completed';
    case SessionStatus.pending:
      return 'pending';
    case SessionStatus.missed:
    case SessionStatus.skipped:
      return 'skipped';
    case SessionStatus.partial:
      return 'partial';
    case SessionStatus.rest:
      return 'pending'; // rest는 session_type으로 구분
  }
}

/// 훈련 세션 카드
/// 홈 화면, 플랜 화면에서 훈련 세션을 표시
class TrainingSessionCard extends StatelessWidget {
  final TrainingZone zone;
  final String title;
  final String? targetPace;
  final String? estimatedTime;
  final SessionStatus status;
  final VoidCallback? onTap;

  const TrainingSessionCard({
    super.key,
    required this.zone,
    required this.title,
    this.targetPace,
    this.estimatedTime,
    this.status = SessionStatus.pending,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
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
              height: 56,
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
                  TrainingTypeBadge(zone: zone),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    title,
                    style: AppTypography.h3.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  if (targetPace != null || estimatedTime != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      [
                        if (targetPace != null) '페이스: $targetPace',
                        if (estimatedTime != null) '예상시간: $estimatedTime',
                      ].join(' · '),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 우측 상태 아이콘
            _buildStatusIcon(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (status) {
      case SessionStatus.completed:
        return const Icon(Icons.check_circle, color: AppColors.success, size: 24);
      case SessionStatus.pending:
        return const Icon(Icons.radio_button_unchecked, color: AppColors.textSecondary, size: 24);
      case SessionStatus.missed:
      case SessionStatus.skipped:
        return const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 24);
      case SessionStatus.partial:
        return const Icon(Icons.check_circle_outline, color: AppColors.warning, size: 24);
      case SessionStatus.rest:
        return const Icon(Icons.remove, color: AppColors.textSecondary, size: 24);
    }
  }
}
