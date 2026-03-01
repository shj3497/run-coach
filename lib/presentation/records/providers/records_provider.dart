import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/workout_log.dart';
import '../../../data/repositories/workout_repository.dart';
import '../../auth/providers/auth_providers.dart';
import '../../providers/data_providers.dart';

// ─── 월 선택 상태 ───

/// 선택된 월 (year, month)
class SelectedMonth {
  final int year;
  final int month;

  const SelectedMonth({required this.year, required this.month});

  SelectedMonth get previous {
    if (month == 1) {
      return SelectedMonth(year: year - 1, month: 12);
    }
    return SelectedMonth(year: year, month: month - 1);
  }

  SelectedMonth get next {
    if (month == 12) {
      return SelectedMonth(year: year + 1, month: 1);
    }
    return SelectedMonth(year: year, month: month + 1);
  }

  /// 현재 월인지 여부
  bool get isCurrentMonth {
    final now = DateTime.now();
    return year == now.year && month == now.month;
  }

  /// 미래 월인지 여부
  bool get isFutureMonth {
    final now = DateTime.now();
    if (year > now.year) return true;
    if (year == now.year && month > now.month) return true;
    return false;
  }

  String get displayLabel {
    return '$year년 $month월';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedMonth && year == other.year && month == other.month;

  @override
  int get hashCode => year.hashCode ^ month.hashCode;
}

/// 선택된 월 상태 Provider (StateProvider)
final selectedMonthProvider = StateProvider<SelectedMonth>((ref) {
  final now = DateTime.now();
  return SelectedMonth(year: now.year, month: now.month);
});

// ─── Providers ───

/// 월간 요약 Provider (실제 workout_repository 연동)
final monthlySummaryProvider =
    FutureProvider<MonthlyWorkoutSummary?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;

  final selectedMonth = ref.watch(selectedMonthProvider);
  final workoutRepo = ref.watch(workoutRepositoryProvider);

  final summary = await workoutRepo.getMonthlySummary(
    user.id,
    selectedMonth.year,
    selectedMonth.month,
  );

  return summary;
});

/// 운동 기록 목록 Provider (선택된 월 기반, 실제 데이터)
final workoutRecordsProvider =
    FutureProvider<List<WorkoutLog>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];

  final selectedMonth = ref.watch(selectedMonthProvider);
  final workoutRepo = ref.watch(workoutRepositoryProvider);

  return await workoutRepo.getWorkoutLogsByMonth(
    user.id,
    selectedMonth.year,
    selectedMonth.month,
  );
});

/// 기록 데이터 존재 여부
final hasRecordsProvider = Provider<bool>((ref) {
  final records = ref.watch(workoutRecordsProvider);
  return records.valueOrNull?.isNotEmpty ?? false;
});
