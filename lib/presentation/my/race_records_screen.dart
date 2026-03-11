import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/vdot_calculator.dart';
import '../../data/models/race_record.dart';
import '../auth/providers/auth_providers.dart';
import '../onboarding/widgets/race_record_form.dart';
import '../onboarding/widgets/race_record_tile.dart';
import '../providers/data_providers.dart';
import 'providers/race_records_provider.dart';

/// D-7 대회 기록 관리 화면
class RaceRecordsScreen extends ConsumerWidget {
  const RaceRecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(raceRecordsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '대회 기록',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 기록 입력 폼
              RaceRecordForm(
                onSubmit: ({
                  required String raceName,
                  required DateTime raceDate,
                  required double distanceKm,
                  required int finishTimeSeconds,
                }) async {
                  await _addRecord(
                    ref,
                    raceName: raceName,
                    raceDate: raceDate,
                    distanceKm: distanceKm,
                    finishTimeSeconds: finishTimeSeconds,
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // 기록 리스트
              recordsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                ),
                error: (_, __) => Center(
                  child: Text(
                    '기록을 불러오는데 실패했습니다',
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                data: (records) {
                  if (records.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxl,
                      ),
                      child: Center(
                        child: Text(
                          '등록된 대회 기록이 없습니다',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '내 대회 기록 (${records.length}건)',
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      ...records.map(
                        (record) => Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.sm,
                          ),
                          child: RaceRecordTile(
                            record: record,
                            onDelete: () => _showDeleteDialog(
                              context,
                              ref,
                              record,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: AppSpacing.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addRecord(
    WidgetRef ref, {
    required String raceName,
    required DateTime raceDate,
    required double distanceKm,
    required int finishTimeSeconds,
  }) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    final vdot = VdotCalculator.calculate(
      distanceKm: distanceKm,
      finishTimeSeconds: finishTimeSeconds,
    );

    final now = DateTime.now();
    final record = RaceRecord(
      id: '', // DB에서 자동 생성
      userId: userId,
      raceName: raceName,
      raceDate: raceDate,
      distanceKm: distanceKm,
      finishTimeSeconds: finishTimeSeconds,
      vdotScore: vdot,
      createdAt: now,
      updatedAt: now,
    );

    final repo = ref.read(raceRecordRepositoryProvider);
    await repo.addRecord(record);
    ref.invalidate(raceRecordsProvider);
  }

  void _showDeleteDialog(
    BuildContext context,
    WidgetRef ref,
    RaceRecord record,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        title: Text(
          '기록 삭제',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        content: Text(
          '\'${record.raceName}\' 기록을 삭제하시겠습니까?',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(
              '취소',
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteRecord(ref, record.id);
            },
            child: Text(
              '삭제',
              style: AppTypography.body.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteRecord(WidgetRef ref, String recordId) async {
    final repo = ref.read(raceRecordRepositoryProvider);
    await repo.deleteRecord(recordId);
    ref.invalidate(raceRecordsProvider);
  }
}
