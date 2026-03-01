import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_typography.dart';

/// 코칭 메시지 카드
/// LLM 코칭 메시지 표시 (인라인 확장/접기)
class CoachingMessageCard extends StatefulWidget {
  final String message;
  final String? timestamp;
  final VoidCallback? onTap;

  const CoachingMessageCard({
    super.key,
    required this.message,
    this.timestamp,
    this.onTap,
  });

  @override
  State<CoachingMessageCard> createState() => _CoachingMessageCardState();
}

class _CoachingMessageCardState extends State<CoachingMessageCard> {
  static const int _collapsedMaxLines = 3;
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        setState(() => _isExpanded = !_isExpanded);
      },
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        alignment: Alignment.topCenter,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.cardPadding),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 좌측 Primary 액센트 바
              Container(
                width: 4,
                constraints: const BoxConstraints(minHeight: 48),
                decoration: BoxDecoration(
                  color: AppColors.primary(context),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // AI 아이콘
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.smart_toy_outlined,
                  size: 20,
                  color: AppColors.primary(context),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // 메시지
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 메시지 텍스트
                    _MessageText(
                      message: widget.message,
                      isExpanded: _isExpanded,
                      collapsedMaxLines: _collapsedMaxLines,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    // 타임스탬프 + 더 보기/접기
                    Row(
                      children: [
                        if (widget.timestamp != null)
                          Text(
                            widget.timestamp!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        const Spacer(),
                        _MoreLessIndicator(
                          message: widget.message,
                          isExpanded: _isExpanded,
                          collapsedMaxLines: _collapsedMaxLines,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 메시지 텍스트 (확장/접기)
class _MessageText extends StatelessWidget {
  final String message;
  final bool isExpanded;
  final int collapsedMaxLines;

  const _MessageText({
    required this.message,
    required this.isExpanded,
    required this.collapsedMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState:
          isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      firstChild: Text(
        message,
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.textPrimary(context),
        ),
        maxLines: collapsedMaxLines,
        overflow: TextOverflow.ellipsis,
      ),
      secondChild: Text(
        message,
        style: AppTypography.bodyLarge.copyWith(
          color: AppColors.textPrimary(context),
        ),
      ),
    );
  }
}

/// "더 보기" / "접기" 인디케이터
/// 텍스트가 maxLines를 초과할 때만 표시
class _MoreLessIndicator extends StatelessWidget {
  final String message;
  final bool isExpanded;
  final int collapsedMaxLines;

  const _MoreLessIndicator({
    required this.message,
    required this.isExpanded,
    required this.collapsedMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 텍스트가 maxLines를 초과하는지 체크
        final textPainter = TextPainter(
          text: TextSpan(
            text: message,
            style: AppTypography.bodyLarge,
          ),
          maxLines: collapsedMaxLines,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        if (!textPainter.didExceedMaxLines && !isExpanded) {
          return const SizedBox.shrink();
        }

        return Text(
          isExpanded ? '접기' : '더 보기',
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
        );
      },
    );
  }
}
