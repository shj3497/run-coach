import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/vdot_calculator.dart';
import '../../data/models/training_session.dart';
import '../../domain/usecases/generate_training_plan.dart';
import '../auth/providers/auth_providers.dart';
import '../onboarding/widgets/date_picker_field.dart';
import '../onboarding/widgets/day_selector.dart';
import '../onboarding/widgets/distance_selector.dart';
import '../onboarding/widgets/time_picker_field.dart';
import '../providers/data_providers.dart';
import '../../domain/usecases/schedule_notifications.dart';
import 'providers/plan_provider.dart';

/// D-5 플랜 생성 화면
/// B-5 목표 설정과 동일한 UI 컴포넌트 사용
class PlanCreateScreen extends ConsumerStatefulWidget {
  const PlanCreateScreen({super.key});

  @override
  ConsumerState<PlanCreateScreen> createState() => _PlanCreateScreenState();
}

class _PlanCreateScreenState extends ConsumerState<PlanCreateScreen> {
  final _raceNameController = TextEditingController();
  DateTime? _raceDate;
  double? _distanceKm;
  int? _goalTimeSeconds;
  bool _justFinish = false;
  int _trainingDaysPerWeek = 3;
  int _trainingWeeks = 12;
  bool _isLoading = false;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    // 프로필에 저장된 주당 훈련일수를 초기값으로
    Future.microtask(() async {
      final user = ref.read(currentUserProvider);
      if (user == null) return;
      final userRepo = ref.read(userRepositoryProvider);
      final profile = await userRepo.getProfile(user.id);
      if (profile?.weeklyAvailableDays != null && mounted) {
        setState(() {
          _trainingDaysPerWeek = profile!.weeklyAvailableDays!;
        });
      }
    });
  }

  @override
  void dispose() {
    _raceNameController.dispose();
    super.dispose();
  }

  bool get _isValid => _distanceKm != null;

  void _updateTrainingWeeks() {
    if (_raceDate != null) {
      final weeks = _raceDate!.difference(DateTime.now()).inDays ~/ 7;
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

  Future<void> _onCreate() async {
    if (!_isValid) return;

    setState(() {
      _isLoading = true;
      _statusMessage = '사용자 정보 확인 중...';
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) throw Exception('로그인이 필요합니다');

      // 0. 플랜 개수 제한 체크 (활성+대기 최대 5개)
      final planRepo = ref.read(planRepositoryProvider);
      final existingPlans = await planRepo.getUserPlans(user.id);
      final activePlanCount = existingPlans
          .where((p) => p.status == 'active' || p.status == 'upcoming')
          .length;
      if (activePlanCount >= 5) {
        throw Exception('활성/대기 중인 플랜은 최대 5개까지 가능합니다. 기존 플랜을 완료하거나 취소해주세요.');
      }

      // 1. VDOT 산출
      // 우선순위: 목표 시간 → 대회 기록 → 경험 기반 기본값
      setState(() => _statusMessage = 'VDOT 분석 중...');

      // 사용자 프로필에서 추가 정보
      final userRepo = ref.read(userRepositoryProvider);
      final profile = await userRepo.getProfile(user.id);
      final experience = profile?.runningExperience ?? 'beginner';

      double vdot;
      final goalTime = _justFinish ? null : _goalTimeSeconds;
      if (goalTime != null && _distanceKm != null) {
        // 목표 시간이 있으면 목표 기반 VDOT 사용
        vdot = VdotCalculator.calculate(
              distanceKm: _distanceKm!,
              finishTimeSeconds: goalTime,
            ) ??
            _defaultVdotForExperience(experience);
      } else {
        // 완주 목표: 대회 기록 → 경험 기본값
        final raceRecordRepo = ref.read(raceRecordRepositoryProvider);
        vdot = await raceRecordRepo.getLatestVdot(user.id) ??
            _defaultVdotForExperience(experience);
      }

      // 2. 날짜 계산
      final startDate = DateTime.now().add(const Duration(days: 1));
      final endDate = startDate.add(Duration(days: _trainingWeeks * 7));

      // 3. GenerateTrainingPlanInput 생성
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
        trainingDaysPerWeek: _trainingDaysPerWeek,
        startDate: startDate,
        endDate: endDate,
        runningExperience: experience,
        weeklyAvailableDays: _trainingDaysPerWeek,
      );

      // 4. 입력 검증
      final errors = input.validate();
      if (errors.isNotEmpty) throw Exception(errors.first);

      // 5. LLM 훈련표 생성 (청크 단위)
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

      // 6. DB 저장
      setState(() => _statusMessage = '훈련표를 저장하고 있습니다...');

      // 기존 활성 플랜 비활성화
      final existingPlan = await planRepo.getActivePlan(user.id);
      if (existingPlan != null) {
        await planRepo.updatePlanStatus(existingPlan.id, 'completed');
      }

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

      // planProvider 새로고침
      ref.read(planProvider.notifier).refresh();
      ref.invalidate(activePlanProvider);

      // 알림 스케줄링
      await scheduleNotificationsIfEnabled(ref);

      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '훈련표가 생성되었습니다!',
              style: AppTypography.body.copyWith(color: Colors.white),
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSpacing.badgeRadius),
            ),
          ),
        );

        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = '';
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '훈련표 생성 실패: $e',
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
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        title: Text(
          '새 플랜 만들기',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
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
                  DatePickerField(
                    label: '대회 날짜',
                    placeholder: '날짜 선택',
                    initialDate: _raceDate,
                    firstDate: DateTime.now().add(const Duration(days: 28)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                    onChanged: (date) {
                      setState(() => _raceDate = date);
                      _updateTrainingWeeks();
                    },
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

                  // 주당 훈련일수
                  _buildLabel(context, '주당 훈련일수'),
                  const SizedBox(height: AppSpacing.sm),
                  DaySelector(
                    selectedDays: _trainingDaysPerWeek,
                    onChanged: (days) =>
                        setState(() => _trainingDaysPerWeek = days),
                    maxDays: 7,
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
                              ? () => setState(() => _trainingWeeks--)
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
                              ? () => setState(() => _trainingWeeks++)
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

                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ),

          // 로딩 오버레이
          if (_isLoading)
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
              onPressed: _isValid && !_isLoading ? _onCreate : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textDisabled(context),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: _isLoading
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
                      style: AppTypography.h3.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
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
