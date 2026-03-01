import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/vdot_calculator.dart';
import '../../data/models/training_session.dart';
import '../../domain/usecases/generate_training_plan.dart';
import '../auth/providers/auth_providers.dart';
import '../home/providers/home_provider.dart';
import '../plan/providers/plan_provider.dart';
import '../providers/data_providers.dart';
import 'providers/onboarding_provider.dart';
import 'widgets/distance_selector.dart';
import 'widgets/time_picker_field.dart';

/// B-5: 목표 설정 화면
class GoalSettingScreen extends ConsumerStatefulWidget {
  const GoalSettingScreen({super.key});

  @override
  ConsumerState<GoalSettingScreen> createState() => _GoalSettingScreenState();
}

class _GoalSettingScreenState extends ConsumerState<GoalSettingScreen> {
  final _raceNameController = TextEditingController();
  DateTime? _raceDate;
  double? _distanceKm;
  int? _goalTimeSeconds;
  bool _justFinish = false;
  int _trainingWeeks = 12;
  bool _isCreatingPlan = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    final state = ref.read(onboardingProvider);
    if (state.goalRaceName != null && state.goalRaceName!.isNotEmpty) {
      _raceNameController.text = state.goalRaceName!;
    }
    _raceDate = state.goalRaceDate;
    _distanceKm = state.goalDistanceKm;
    _goalTimeSeconds = state.goalTimeSeconds;
    _justFinish = state.justFinishGoal;
    if (state.trainingWeeks != null) {
      _trainingWeeks = state.trainingWeeks!;
    }
  }

  @override
  void dispose() {
    _raceNameController.dispose();
    super.dispose();
  }

  bool get _isValid => _distanceKm != null;

  void _updateTrainingWeeks() {
    if (_raceDate != null) {
      final weeks =
          _raceDate!.difference(DateTime.now()).inDays ~/ 7;
      setState(() {
        _trainingWeeks = weeks.clamp(4, 24);
      });
    }
  }

  static double _defaultVdotForExperience(String experience) {
    switch (experience) {
      case 'advanced':
        return 50.0;
      case 'intermediate':
        return 40.0;
      default:
        return 30.0;
    }
  }

  Future<void> _onComplete() async {
    final notifier = ref.read(onboardingProvider.notifier);

    notifier.updateGoal(
      goalRaceName: _raceNameController.text.isNotEmpty
          ? _raceNameController.text
          : null,
      goalRaceDate: _raceDate,
      goalDistanceKm: _distanceKm,
      goalTimeSeconds: _justFinish ? null : _goalTimeSeconds,
      justFinishGoal: _justFinish,
      trainingWeeks: _trainingWeeks,
    );

    setState(() {
      _isCreatingPlan = true;
      _statusMessage = '설정을 저장하고 있습니다...';
    });

    final success = await notifier.completeOnboarding();
    if (!success || !mounted) {
      setState(() {
        _isCreatingPlan = false;
        _statusMessage = '';
      });
      return;
    }

    // 첫 훈련표 자동 생성
    if (_distanceKm != null) {
      await _createFirstPlan();
    }

    if (mounted) {
      setState(() {
        _isCreatingPlan = false;
        _statusMessage = '';
      });
      context.go('/home');
    }
  }

  Future<void> _createFirstPlan() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) return;

      final onboardingState = ref.read(onboardingProvider);
      final experience = onboardingState.runningExperience ?? 'beginner';
      final trainingDaysPerWeek = onboardingState.weeklyAvailableDays ?? 3;

      // VDOT 산출
      setState(() => _statusMessage = 'VDOT 분석 중...');

      double vdot;
      final goalTime = _justFinish ? null : _goalTimeSeconds;
      if (goalTime != null && _distanceKm != null) {
        vdot = VdotCalculator.calculate(
              distanceKm: _distanceKm!,
              finishTimeSeconds: goalTime,
            ) ??
            _defaultVdotForExperience(experience);
      } else {
        final raceRecordRepo = ref.read(raceRecordRepositoryProvider);
        vdot = await raceRecordRepo.getLatestVdot(user.id) ??
            _defaultVdotForExperience(experience);
      }

      // 날짜 계산
      final startDate = DateTime.now().add(const Duration(days: 1));
      final endDate = startDate.add(Duration(days: _trainingWeeks * 7));

      // GenerateTrainingPlanInput 생성
      final input = GenerateTrainingPlanInput(
        userId: user.id,
        vdotScore: vdot,
        goalDistanceKm: _distanceKm!,
        goalTimeSeconds: _justFinish ? null : _goalTimeSeconds,
        goalRaceName: _raceNameController.text.isNotEmpty
            ? _raceNameController.text
            : null,
        goalRaceDate: _raceDate,
        totalWeeks: _trainingWeeks,
        trainingDaysPerWeek: trainingDaysPerWeek,
        startDate: startDate,
        endDate: endDate,
        runningExperience: experience,
        weeklyAvailableDays: trainingDaysPerWeek,
      );

      // 입력 검증
      final errors = input.validate();
      if (errors.isNotEmpty) throw Exception(errors.first);

      // LLM 훈련표 생성
      setState(() => _statusMessage = 'AI가 훈련표를 작성하고 있습니다...');
      final useCase = ref.read(generateTrainingPlanProvider);
      final result = await useCase.execute(
        input,
        onChunkProgress: (current, total) {
          if (mounted) {
            setState(() => _statusMessage =
                'AI가 훈련표를 작성하고 있습니다... ($current/$total)');
          }
        },
      );

      // DB 저장
      setState(() => _statusMessage = '훈련표를 저장하고 있습니다...');
      final planRepo = ref.read(planRepositoryProvider);

      // weekNumberToSessions 맵 구성
      final weekNumberToSessions = <int, List<TrainingSession>>{};
      for (final week in result.weeks) {
        weekNumberToSessions[week.weekNumber] = result.sessions
            .where((s) =>
                !s.sessionDate.isBefore(week.startDate) &&
                !s.sessionDate.isAfter(week.endDate))
            .toList();
      }

      // 플랜 + 주차 + 세션 일괄 저장
      final savedPlan = await planRepo.createPlanWithMapping(
        plan: result.plan,
        weeks: result.weeks,
        weekNumberToSessions: weekNumberToSessions,
      );

      // 플랜 활성화
      await planRepo.updatePlanStatus(savedPlan.id, 'active');

      // 코칭 메시지 저장 (planId 연결)
      final coachingRepo = ref.read(coachingRepositoryProvider);
      await coachingRepo.createMessage(
        result.coachingMessage.copyWith(planId: savedPlan.id),
      );

      // Provider 새로고침
      ref.read(planProvider.notifier).refresh();
      ref.invalidate(activePlanProvider);
      ref.invalidate(homeStateProvider);
    } catch (e) {
      // 훈련표 생성 실패 시 에러만 표시하고 홈으로 이동은 계속 진행
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '훈련표 자동 생성에 실패했습니다. 플랜 탭에서 다시 시도해주세요.',
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '5/5',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.background(context),
        leading: _isCreatingPlan
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => context.go('/onboarding/race-records'),
              ),
      ),
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    '목표를 설정해주세요',
                    style: AppTypography.h1.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),

                  // 대회명 (선택)
                  _buildLabel(context, '대회명 (선택)'),
                  const SizedBox(height: AppSpacing.sm),
                  TextField(
                    controller: _raceNameController,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textPrimary(context),
                    ),
                    decoration: _inputDecoration(context, '예: 2026 서울마라톤'),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 대회 날짜 (선택)
                  _buildLabel(context, '대회 날짜 (선택)'),
                  const SizedBox(height: AppSpacing.sm),
                  GestureDetector(
                    onTap: () => _showDatePicker(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface(context),
                        border: Border.all(color: AppColors.divider(context)),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.badgeRadius),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _raceDate != null
                                ? '${_raceDate!.year}년 ${_raceDate!.month.toString().padLeft(2, '0')}월 ${_raceDate!.day.toString().padLeft(2, '0')}일'
                                : '날짜 선택',
                            style: AppTypography.body.copyWith(
                              color: _raceDate != null
                                  ? AppColors.textPrimary(context)
                                  : AppColors.textSecondary,
                            ),
                          ),
                          const Icon(
                            Icons.calendar_today_rounded,
                            size: 20,
                            color: AppColors.textSecondary,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 목표 거리 (필수)
                  _buildLabel(context, '목표 거리', required: true),
                  const SizedBox(height: AppSpacing.sm),
                  DistanceSelector(
                    selectedDistanceKm: _distanceKm,
                    onChanged: (km) => setState(() => _distanceKm = km),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 목표 시간
                  _buildLabel(context, '목표 시간'),
                  const SizedBox(height: AppSpacing.sm),
                  TimePickerField(
                    label: '',
                    initialSeconds: _goalTimeSeconds,
                    enabled: !_justFinish,
                    onChanged: (seconds) =>
                        setState(() => _goalTimeSeconds = seconds),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // 완주가 목표 체크박스
                  GestureDetector(
                    onTap: () => setState(() {
                      _justFinish = !_justFinish;
                      if (_justFinish) _goalTimeSeconds = null;
                    }),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: _justFinish
                                ? AppColors.primary(context)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: _justFinish
                                  ? AppColors.primary(context)
                                  : AppColors.divider(context),
                              width: 2,
                            ),
                          ),
                          child: _justFinish
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '완주가 목표입니다',
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 훈련 기간
                  _buildLabel(context, '훈련 기간'),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.cardPadding),
                    decoration: BoxDecoration(
                      color: AppColors.surface(context),
                      borderRadius:
                          BorderRadius.circular(AppSpacing.cardRadius),
                      border: Border.all(color: AppColors.divider(context)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: _trainingWeeks > 4
                              ? () =>
                                  setState(() => _trainingWeeks--)
                              : null,
                          icon: Icon(
                            Icons.remove_circle_outline,
                            color: _trainingWeeks > 4
                                ? AppColors.primary(context)
                                : AppColors.textDisabled(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        Text(
                          '$_trainingWeeks주',
                          style: AppTypography.h1.copyWith(
                            color: AppColors.primary(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.lg),
                        IconButton(
                          onPressed: _trainingWeeks < 24
                              ? () =>
                                  setState(() => _trainingWeeks++)
                              : null,
                          icon: Icon(
                            Icons.add_circle_outline,
                            color: _trainingWeeks < 24
                                ? AppColors.primary(context)
                                : AppColors.textDisabled(context),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 에러
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.lg),
                      child: Text(
                        state.error!,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ),

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          // 로딩 오버레이
          if (_isCreatingPlan)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      _statusMessage,
                      style: AppTypography.body.copyWith(
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed:
                  _isValid && !state.isLoading && !_isCreatingPlan
                      ? _onComplete
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textDisabled(context),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: _isCreatingPlan || state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '훈련표 생성하기',
                      style:
                          AppTypography.h3.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDatePicker(BuildContext context) {
    final now = DateTime.now();
    final minDate = now.add(const Duration(days: 28));
    final maxDate = now.add(const Duration(days: 365));
    final initDate = _raceDate ?? DateTime.now().add(const Duration(days: 84));

    int selectedYear = initDate.year;
    int selectedMonth = initDate.month;
    int selectedDay = initDate.day;

    // 년도 범위: minDate.year ~ maxDate.year
    final years = List.generate(
      maxDate.year - minDate.year + 1,
      (i) => minDate.year + i,
    );

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        '취소',
                        style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Text(
                      '대회 날짜',
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        final maxDay =
                            DateTime(selectedYear, selectedMonth + 1, 0).day;
                        final safeDay =
                            selectedDay > maxDay ? maxDay : selectedDay;
                        var date =
                            DateTime(selectedYear, selectedMonth, safeDay);
                        // 범위 보정
                        if (date.isBefore(minDate)) date = minDate;
                        if (date.isAfter(maxDate)) date = maxDate;
                        setState(() => _raceDate = date);
                        _updateTrainingWeeks();
                        Navigator.pop(ctx);
                      },
                      child: Text(
                        '확인',
                        style: AppTypography.body.copyWith(
                          color: AppColors.primary(context),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.divider(context)),
              Expanded(
                child: Row(
                  children: [
                    // 년
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: years.indexOf(initDate.year),
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                          background:
                              AppColors.primary(context).withValues(alpha: 0.08),
                        ),
                        onSelectedItemChanged: (i) {
                            HapticFeedback.selectionClick();
                            selectedYear = years[i];
                        },
                        children: years.map((y) {
                          return Center(
                            child: Text(
                              '$y년',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    // 월
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: initDate.month - 1,
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                          background:
                              AppColors.primary(context).withValues(alpha: 0.08),
                        ),
                        onSelectedItemChanged: (i) {
                            HapticFeedback.selectionClick();
                            selectedMonth = i + 1;
                        },
                        children: List.generate(12, (i) {
                          return Center(
                            child: Text(
                              '${i + 1}월',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                    // 일
                    Expanded(
                      child: CupertinoPicker(
                        scrollController: FixedExtentScrollController(
                          initialItem: initDate.day - 1,
                        ),
                        itemExtent: 40,
                        diameterRatio: 1.2,
                        selectionOverlay:
                            CupertinoPickerDefaultSelectionOverlay(
                          background:
                              AppColors.primary(context).withValues(alpha: 0.08),
                        ),
                        onSelectedItemChanged: (i) {
                            HapticFeedback.selectionClick();
                            selectedDay = i + 1;
                        },
                        children: List.generate(31, (i) {
                          return Center(
                            child: Text(
                              '${i + 1}일',
                              style: AppTypography.body.copyWith(
                                color: AppColors.textPrimary(context),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel(BuildContext context, String label,
      {bool required = false}) {
    return Row(
      children: [
        Text(
          label,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
        if (required)
          Text(
            ' *',
            style: AppTypography.body.copyWith(color: AppColors.error),
          ),
      ],
    );
  }

  InputDecoration _inputDecoration(BuildContext context, String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTypography.body.copyWith(
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.surface(context),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        borderSide: BorderSide(color: AppColors.divider(context)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        borderSide: BorderSide(color: AppColors.divider(context)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
        borderSide: BorderSide(
          color: AppColors.primary(context),
          width: 2,
        ),
      ),
    );
  }
}
