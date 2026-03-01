import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Shimmer 애니메이션을 제공하는 컨테이너
///
/// 자식 위젯들([SkeletonBox], [SkeletonCircle])에 shimmer 효과를 전파합니다.
/// 화면 단위로 한 번만 감싸면 됩니다.
class SkeletonShimmer extends StatefulWidget {
  final Widget child;

  const SkeletonShimmer({super.key, required this.child});

  @override
  State<SkeletonShimmer> createState() => _SkeletonShimmerState();
}

class _SkeletonShimmerState extends State<SkeletonShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return _ShimmerProvider(
          progress: _controller.value,
          child: child!,
        );
      },
      child: widget.child,
    );
  }
}

/// InheritedWidget로 shimmer progress를 하위에 전달
class _ShimmerProvider extends InheritedWidget {
  final double progress;

  const _ShimmerProvider({
    required this.progress,
    required super.child,
  });

  static _ShimmerProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerProvider>();
  }

  @override
  bool updateShouldNotify(_ShimmerProvider oldWidget) {
    return progress != oldWidget.progress;
  }
}

/// 직사각형 스켈레톤 (텍스트 라인, 카드, 바 등)
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double? borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final shimmer = _ShimmerProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF2F2F7);

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [baseColor, highlightColor, baseColor],
      stops: _calculateStops(shimmer?.progress ?? 0),
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(borderRadius ?? 6),
      ),
    );
  }
}

/// 원형 스켈레톤 (아바타, 아이콘 등)
class SkeletonCircle extends StatelessWidget {
  final double size;

  const SkeletonCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    final shimmer = _ShimmerProvider.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseColor = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFE5E5EA);
    final highlightColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFFF2F2F7);

    final gradient = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [baseColor, highlightColor, baseColor],
      stops: _calculateStops(shimmer?.progress ?? 0),
    );

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Shimmer gradient stops 계산
List<double> _calculateStops(double progress) {
  final center = progress;
  final start = (center - 0.3).clamp(0.0, 1.0);
  final end = (center + 0.3).clamp(0.0, 1.0);
  return [start, center.clamp(0.0, 1.0), end];
}

// ---------------------------------------------------------------------------
// 화면별 스켈레톤 프리셋
// ---------------------------------------------------------------------------

/// 홈 화면 스켈레톤
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 인사말
            const SkeletonBox(width: 180, height: 28),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(width: 120, height: 16),
            const SizedBox(height: AppSpacing.xl),

            // 오늘의 훈련 섹션
            const SkeletonBox(width: 100, height: 22),
            const SizedBox(height: AppSpacing.sm),
            _buildSessionCardSkeleton(context),
            const SizedBox(height: AppSpacing.xl),

            // 주간 진행률 섹션
            const SkeletonBox(width: 100, height: 22),
            const SizedBox(height: AppSpacing.sm),
            _buildProgressSkeleton(context),
            const SizedBox(height: AppSpacing.xl),

            // 코칭 메시지 섹션
            const SkeletonBox(width: 100, height: 22),
            const SizedBox(height: AppSpacing.sm),
            _buildCoachingSkeleton(context),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionCardSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 4, height: 48, borderRadius: 2),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 60, height: 14),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 140, height: 18),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 100, height: 14),
              ],
            ),
          ),
          SkeletonCircle(size: 24),
        ],
      ),
    );
  }

  Widget _buildProgressSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: const Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 80, height: 14),
              SkeletonBox(width: 40, height: 14),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 8, borderRadius: 4),
          SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SkeletonBox(width: 80, height: 14),
              SkeletonBox(width: 40, height: 14),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(height: 8, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildCoachingSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 4, height: 48, borderRadius: 2),
          SizedBox(width: AppSpacing.md),
          SkeletonCircle(size: 20),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(height: 16),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(height: 16),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 160, height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 플랜 화면 스켈레톤
class PlanScreenSkeleton extends StatelessWidget {
  const PlanScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 주차 네비게이션
            const Center(child: SkeletonBox(width: 200, height: 24)),
            const SizedBox(height: AppSpacing.sm),
            const Center(child: SkeletonBox(width: 140, height: 14)),
            const SizedBox(height: AppSpacing.xl),

            // 세션 카드 4개
            for (int i = 0; i < 4; i++) ...[
              _buildSessionSkeleton(context),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSessionSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: const Row(
        children: [
          SkeletonBox(width: 4, height: 48, borderRadius: 2),
          SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 50, height: 12),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 130, height: 18),
                SizedBox(height: AppSpacing.sm),
                SkeletonBox(width: 90, height: 12),
              ],
            ),
          ),
          SkeletonCircle(size: 24),
        ],
      ),
    );
  }
}

/// 기록 화면 - 월간 요약 스켈레톤 (StatCard 그리드와 동일 구조)
class RecordsSummarySkeleton extends StatelessWidget {
  const RecordsSummarySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.6,
        children: List.generate(4, (_) => _buildStatSkeleton(context)),
      ),
    );
  }

  /// StatCard와 동일: padding md, borderRadius md, label → xs → value
  Widget _buildStatSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SkeletonBox(width: 50, height: 14),
          SizedBox(height: AppSpacing.xs),
          SkeletonBox(width: 80, height: 26),
        ],
      ),
    );
  }
}

/// 기록 화면 - 운동 기록 리스트 스켈레톤 (_buildRecordItem과 동일 구조)
class RecordsListSkeleton extends StatelessWidget {
  const RecordsListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: [
          for (int i = 0; i < 3; i++) ...[
            _buildRecordSkeleton(context),
            if (i < 2) const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  /// _buildRecordItem과 동일: Column(Row(date+badge+chevron), body text)
  Widget _buildRecordSkeleton(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 65, height: 14),
              SizedBox(width: AppSpacing.sm),
              SkeletonBox(
                width: 48,
                height: 26,
                borderRadius: AppSpacing.badgeRadius,
              ),
              Spacer(),
              SkeletonBox(width: 20, height: 20, borderRadius: 4),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          SkeletonBox(width: 200, height: 16),
        ],
      ),
    );
  }
}

/// 기록 화면 전체 스켈레톤 (요약 + 리스트 통합)
class RecordsScreenSkeleton extends StatelessWidget {
  const RecordsScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        RecordsSummarySkeleton(),
        SizedBox(height: AppSpacing.xl),
        RecordsListSkeleton(),
      ],
    );
  }
}

/// 마이페이지 스켈레톤
class MyPageSkeleton extends StatelessWidget {
  const MyPageSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xl),
            // 프로필
            const SkeletonCircle(size: 72),
            const SizedBox(height: AppSpacing.md),
            const SkeletonBox(width: 80, height: 22),
            const SizedBox(height: AppSpacing.sm),
            const SkeletonBox(width: 100, height: 16),
            const SizedBox(height: AppSpacing.xxl),

            // 메뉴 그룹
            Container(
              padding: const EdgeInsets.all(AppSpacing.cardPadding),
              decoration: BoxDecoration(
                color: AppColors.surface(context),
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              ),
              child: const Column(
                children: [
                  _MenuItemSkeleton(),
                  SizedBox(height: AppSpacing.md),
                  _MenuItemSkeleton(),
                  SizedBox(height: AppSpacing.md),
                  _MenuItemSkeleton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuItemSkeleton extends StatelessWidget {
  const _MenuItemSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SkeletonCircle(size: 24),
        SizedBox(width: AppSpacing.md),
        Expanded(child: SkeletonBox(width: 120, height: 16)),
      ],
    );
  }
}
