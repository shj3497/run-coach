import 'dart:convert';

import '../../core/utils/vdot_calculator.dart';
import '../../data/models/coaching_message.dart';
import '../../data/models/training_plan.dart';
import '../../data/models/training_session.dart';
import '../../data/models/training_week.dart';
import '../../data/services/llm/llm_prompts.dart';
import '../../data/services/llm/llm_provider.dart';
import '../../data/services/llm/training_plan_response.dart';

/// 훈련표 생성 유스케이스
///
/// VDOT 기반 페이스 존 계산(룰 기반) + LLM 주기화 훈련표 구성을 수행합니다.
///
/// 처리 흐름:
/// 1. VDOT -> 페이스 존 계산 (룰 기반)
/// 2. 주기화 배분 결정 (base/build/peak/taper 비율)
/// 3. LLM에 context 전달하여 세부 훈련표 요청
/// 4. LLM 응답 파싱 -> TrainingPlan + TrainingWeeks + TrainingSessions 객체 생성
class GenerateTrainingPlan {
  final LLMProvider _llmProvider;

  const GenerateTrainingPlan({
    required LLMProvider llmProvider,
  }) : _llmProvider = llmProvider;

  /// 훈련표 생성 실행
  ///
  /// [input] 훈련표 생성에 필요한 입력 데이터
  /// 반환: [GenerateTrainingPlanResult] 생성된 훈련표 전체 데이터
  ///
  /// 예외:
  /// - [LLMException] LLM 호출 실패 시
  /// - [FormatException] LLM 응답 파싱 실패 시
  Future<GenerateTrainingPlanResult> execute(
    GenerateTrainingPlanInput input,
  ) async {
    // 1. VDOT -> 페이스 존 계산
    final paceZones = VdotCalculator.getPaceZonesStructured(input.vdotScore);

    // 2. 주기화 배분 결정
    final periodization = _calculatePeriodization(input.totalWeeks);

    // 3. LLM context 구성
    final context = _buildLLMContext(
      input: input,
      paceZones: paceZones,
      periodization: periodization,
    );

    // 4. LLM 호출
    final llmResponse = await _callLLM(context);

    // 5. LLM 응답 파싱
    final parsedResponse = _parseLLMResponse(llmResponse);

    // 6. 모델 객체 생성
    final result = _buildResult(
      input: input,
      paceZones: paceZones,
      parsedResponse: parsedResponse,
      llmContext: context,
      llmResponse: llmResponse,
    );

    return result;
  }

  // ---------------------------------------------------------------------------
  // 주기화 배분 계산
  // ---------------------------------------------------------------------------

  /// 총 주수에 따른 주기화 단계별 주수 배분
  ///
  /// - base: 약 30% (기초 체력)
  /// - build: 약 40% (강도 증가)
  /// - peak: 약 15~20% (절정)
  /// - taper: 약 10~15% (대회 전 감량)
  static Periodization _calculatePeriodization(int totalWeeks) {
    if (totalWeeks <= 4) {
      // 4주 이하: 단축 프로그램
      return Periodization(
        baseWeeks: 1,
        buildWeeks: (totalWeeks - 2).clamp(1, totalWeeks),
        peakWeeks: totalWeeks >= 3 ? 1 : 0,
        taperWeeks: 1,
      );
    }

    if (totalWeeks <= 8) {
      // 5~8주
      final taper = 1;
      final peak = 1;
      final base = (totalWeeks * 0.30).round().clamp(1, totalWeeks);
      final build = totalWeeks - base - peak - taper;
      return Periodization(
        baseWeeks: base,
        buildWeeks: build.clamp(1, totalWeeks),
        peakWeeks: peak,
        taperWeeks: taper,
      );
    }

    // 9주 이상: 표준 배분
    final taper = (totalWeeks * 0.10).round().clamp(1, 3);
    final peak = (totalWeeks * 0.15).round().clamp(1, 3);
    final base = (totalWeeks * 0.30).round().clamp(2, totalWeeks);
    final build = totalWeeks - base - peak - taper;

    return Periodization(
      baseWeeks: base,
      buildWeeks: build.clamp(2, totalWeeks),
      peakWeeks: peak,
      taperWeeks: taper,
    );
  }

  /// 주기화 배분을 외부에서도 조회할 수 있도록 공개
  static Periodization calculatePeriodization(int totalWeeks) {
    return _calculatePeriodization(totalWeeks);
  }

  // ---------------------------------------------------------------------------
  // LLM Context 구성
  // ---------------------------------------------------------------------------

  /// LLM에 전달할 context JSON 구성
  Map<String, dynamic> _buildLLMContext({
    required GenerateTrainingPlanInput input,
    required PaceZones paceZones,
    required Periodization periodization,
  }) {
    final context = <String, dynamic>{
      'vdot_score': input.vdotScore,
      'pace_zones': paceZones.toContextJson(),
      'goal': {
        'distance_km': input.goalDistanceKm,
        'distance_label': _getDistanceLabel(input.goalDistanceKm),
        if (input.goalTimeSeconds != null)
          'time_seconds': input.goalTimeSeconds,
        if (input.goalTimeSeconds != null)
          'time_display': _formatTime(input.goalTimeSeconds!),
        if (input.goalRaceName != null) 'race_name': input.goalRaceName,
        'is_finish_goal': input.goalTimeSeconds == null,
      },
      'training_info': {
        'total_weeks': input.totalWeeks,
        'training_days_per_week': input.trainingDaysPerWeek,
        'start_date': _formatDate(input.startDate),
        'end_date': _formatDate(input.endDate),
        'periodization': {
          'base_weeks': periodization.baseWeeks,
          'build_weeks': periodization.buildWeeks,
          'peak_weeks': periodization.peakWeeks,
          'taper_weeks': periodization.taperWeeks,
        },
      },
      'user_info': {
        'experience': input.runningExperience ?? 'beginner',
        if (input.weeklyAvailableDays != null)
          'weekly_available_days': input.weeklyAvailableDays,
        if (input.currentWeeklyDistanceKm != null)
          'current_weekly_distance_km': input.currentWeeklyDistanceKm,
        if (input.recentAvgPaceSecondsPerKm != null)
          'recent_avg_pace': _formatPace(input.recentAvgPaceSecondsPerKm!),
      },
    };

    // 예상 레이스 시간 추가
    final estimatedTimes =
        VdotCalculator.estimateAllRaceTimesFormatted(input.vdotScore);
    context['estimated_race_times'] = estimatedTimes;

    return context;
  }

  // ---------------------------------------------------------------------------
  // LLM 호출
  // ---------------------------------------------------------------------------

  /// LLM에 훈련표 생성 요청
  Future<LLMResponse> _callLLM(Map<String, dynamic> context) async {
    final contextJson = const JsonEncoder.withIndent('  ').convert(context);
    final userPrompt = LLMPrompts.trainingPlanUserPrompt(contextJson);

    try {
      final response = await _llmProvider.generateJson(
        systemPrompt: LLMPrompts.trainingPlanSystemPrompt,
        userPrompt: userPrompt,
        temperature: 0.7,
        maxTokens: 8000,
      );
      return response;
    } on LLMException {
      rethrow;
    } catch (e) {
      throw LLMException(
        message: 'LLM 훈련표 생성 실패',
        originalError: e,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // LLM 응답 파싱
  // ---------------------------------------------------------------------------

  /// LLM JSON 응답을 TrainingPlanResponse로 파싱
  TrainingPlanResponse _parseLLMResponse(LLMResponse response) {
    try {
      final json = jsonDecode(response.content) as Map<String, dynamic>;
      return TrainingPlanResponse.fromJson(json);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw FormatException('LLM 응답 JSON 파싱 실패: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 결과 모델 빌드
  // ---------------------------------------------------------------------------

  /// 파싱된 응답으로부터 DB 저장용 모델 객체를 생성
  GenerateTrainingPlanResult _buildResult({
    required GenerateTrainingPlanInput input,
    required PaceZones paceZones,
    required TrainingPlanResponse parsedResponse,
    required Map<String, dynamic> llmContext,
    required LLMResponse llmResponse,
  }) {
    final now = DateTime.now();

    // TrainingPlan 생성
    // id는 DB에서 자동 생성되므로 임시값 사용
    final plan = TrainingPlan(
      id: '', // DB에서 자동 생성
      userId: input.userId,
      planName: parsedResponse.planName.isNotEmpty
          ? parsedResponse.planName
          : _generateDefaultPlanName(input),
      status: 'upcoming',
      goalRaceName: input.goalRaceName,
      goalRaceDate: input.goalRaceDate,
      goalDistanceKm: input.goalDistanceKm,
      goalTimeSeconds: input.goalTimeSeconds,
      vdotScore: input.vdotScore,
      totalWeeks: input.totalWeeks,
      startDate: input.startDate,
      endDate: input.endDate,
      trainingDaysPerWeek: input.trainingDaysPerWeek,
      paceZones: paceZones.toJson(),
      llmContextSnapshot: llmContext,
      createdAt: now,
      updatedAt: now,
    );

    // TrainingWeeks + TrainingSessions 생성
    final weeks = <TrainingWeek>[];
    final sessions = <TrainingSession>[];

    for (final weekResponse in parsedResponse.weeks) {
      final weekStartDate = input.startDate.add(
        Duration(days: (weekResponse.weekNumber - 1) * 7),
      );
      final weekEndDate = weekStartDate.add(const Duration(days: 6));

      final week = TrainingWeek(
        id: '', // DB에서 자동 생성
        planId: '', // plan 저장 후 채워짐
        weekNumber: weekResponse.weekNumber,
        startDate: weekStartDate,
        endDate: weekEndDate,
        phase: weekResponse.phase,
        targetDistanceKm: weekResponse.targetDistanceKm,
        weeklySummary: weekResponse.weeklySummary,
        createdAt: now,
      );
      weeks.add(week);

      // 세션 생성
      for (final sessionResponse in weekResponse.sessions) {
        // day_of_week에서 실제 날짜 계산
        // day_of_week: 1=월 ~ 7=일
        // weekStartDate는 해당 주의 시작일 (월요일 기준)
        final dayOffset = sessionResponse.dayOfWeek - 1;
        final sessionDate = weekStartDate.add(Duration(days: dayOffset));

        final session = TrainingSession(
          id: '', // DB에서 자동 생성
          weekId: '', // week 저장 후 채워짐
          planId: '', // plan 저장 후 채워짐
          sessionDate: sessionDate,
          dayOfWeek: sessionResponse.dayOfWeek,
          sessionType: sessionResponse.sessionType,
          title: sessionResponse.title,
          description: sessionResponse.description,
          targetDistanceKm: sessionResponse.targetDistanceKm,
          targetDurationMinutes: sessionResponse.targetDurationMinutes,
          targetPace: sessionResponse.targetPace,
          workoutDetail: sessionResponse.workoutDetail,
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        );
        sessions.add(session);
      }
    }

    // 코칭 메시지 (plan_overview)
    final coachingMessage = CoachingMessage(
      id: '', // DB에서 자동 생성
      userId: input.userId,
      messageType: 'plan_overview',
      title: '훈련 계획이 준비되었습니다',
      content: parsedResponse.planOverview,
      llmModel: llmResponse.model,
      llmPromptSnapshot: llmContext,
      tokenUsage: llmResponse.tokenUsageToJson(),
      createdAt: now,
    );

    return GenerateTrainingPlanResult(
      plan: plan,
      weeks: weeks,
      sessions: sessions,
      coachingMessage: coachingMessage,
      paceZones: paceZones,
    );
  }

  // ---------------------------------------------------------------------------
  // 헬퍼 메서드
  // ---------------------------------------------------------------------------

  /// 기본 플랜 이름 생성
  String _generateDefaultPlanName(GenerateTrainingPlanInput input) {
    final distanceLabel = _getDistanceLabel(input.goalDistanceKm);
    if (input.goalTimeSeconds != null) {
      final timeStr = _formatTime(input.goalTimeSeconds!);
      return '$distanceLabel $timeStr 도전';
    }
    return '$distanceLabel 완주 도전';
  }

  /// 거리를 한글 라벨로 변환
  static String _getDistanceLabel(double distanceKm) {
    final key = VdotCalculator.getStandardDistanceKey(distanceKm);
    if (key != null) {
      return VdotCalculator.standardDistanceLabels[key] ?? '${distanceKm}km';
    }
    return '${distanceKm}km';
  }

  /// 초를 시간 형식으로 변환
  static String _formatTime(int totalSeconds) {
    final hours = totalSeconds ~/ 3600;
    final minutes = (totalSeconds % 3600) ~/ 60;
    final seconds = totalSeconds % 60;

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// 초/km를 페이스 형식으로 변환
  static String _formatPace(int secondsPerKm) {
    final minutes = secondsPerKm ~/ 60;
    final seconds = secondsPerKm % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}/km';
  }

  /// DateTime을 YYYY-MM-DD 형식으로 변환
  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

// =============================================================================
// 입출력 모델
// =============================================================================

/// 훈련표 생성 입력 데이터
class GenerateTrainingPlanInput {
  /// 사용자 ID
  final String userId;

  /// VDOT 점수 (대회 기록 또는 직접 입력으로 산출)
  final double vdotScore;

  /// 목표 거리 (km) - 5.0 / 10.0 / 21.0975 / 42.195
  final double goalDistanceKm;

  /// 목표 완주 시간 (초). null이면 완주 목표
  final int? goalTimeSeconds;

  /// 목표 대회 이름
  final String? goalRaceName;

  /// 목표 대회 날짜
  final DateTime? goalRaceDate;

  /// 총 훈련 주수
  final int totalWeeks;

  /// 주간 훈련일수 (1~5)
  final int trainingDaysPerWeek;

  /// 훈련 시작일
  final DateTime startDate;

  /// 훈련 종료일
  final DateTime endDate;

  /// 러닝 경험 수준 (beginner / intermediate / advanced)
  final String? runningExperience;

  /// 주간 가용 훈련일수
  final int? weeklyAvailableDays;

  /// 현재 주간 러닝 거리 (km) - HealthKit 데이터 기반
  final double? currentWeeklyDistanceKm;

  /// 최근 평균 페이스 (초/km) - HealthKit 데이터 기반
  final int? recentAvgPaceSecondsPerKm;

  const GenerateTrainingPlanInput({
    required this.userId,
    required this.vdotScore,
    required this.goalDistanceKm,
    this.goalTimeSeconds,
    this.goalRaceName,
    this.goalRaceDate,
    required this.totalWeeks,
    required this.trainingDaysPerWeek,
    required this.startDate,
    required this.endDate,
    this.runningExperience,
    this.weeklyAvailableDays,
    this.currentWeeklyDistanceKm,
    this.recentAvgPaceSecondsPerKm,
  });

  /// 입력 유효성 검증
  ///
  /// 반환: 에러 메시지 목록 (비어 있으면 유효)
  List<String> validate() {
    final errors = <String>[];

    if (vdotScore < 20 || vdotScore > 85) {
      errors.add('VDOT 점수는 20~85 범위여야 합니다.');
    }
    if (goalDistanceKm <= 0) {
      errors.add('목표 거리는 0보다 커야 합니다.');
    }
    if (totalWeeks < 4 || totalWeeks > 52) {
      errors.add('훈련 기간은 4~52주 범위여야 합니다.');
    }
    if (trainingDaysPerWeek < 1 || trainingDaysPerWeek > 7) {
      errors.add('주간 훈련일수는 1~7일 범위여야 합니다.');
    }
    if (endDate.isBefore(startDate)) {
      errors.add('종료일은 시작일 이후여야 합니다.');
    }
    if (goalTimeSeconds != null && goalTimeSeconds! <= 0) {
      errors.add('목표 시간은 0보다 커야 합니다.');
    }

    return errors;
  }
}

/// 훈련표 생성 결과
class GenerateTrainingPlanResult {
  /// 생성된 훈련 플랜
  final TrainingPlan plan;

  /// 생성된 주차 목록
  final List<TrainingWeek> weeks;

  /// 생성된 세션 목록
  final List<TrainingSession> sessions;

  /// 플랜 개요 코칭 메시지
  final CoachingMessage coachingMessage;

  /// 계산된 페이스 존
  final PaceZones paceZones;

  const GenerateTrainingPlanResult({
    required this.plan,
    required this.weeks,
    required this.sessions,
    required this.coachingMessage,
    required this.paceZones,
  });
}

/// 주기화 배분 정보
class Periodization {
  /// 기초 체력 단계 주수
  final int baseWeeks;

  /// 강도 증가 단계 주수
  final int buildWeeks;

  /// 절정 단계 주수
  final int peakWeeks;

  /// 테이퍼(감량) 단계 주수
  final int taperWeeks;

  const Periodization({
    required this.baseWeeks,
    required this.buildWeeks,
    required this.peakWeeks,
    required this.taperWeeks,
  });

  /// 총 주수
  int get totalWeeks => baseWeeks + buildWeeks + peakWeeks + taperWeeks;

  /// 주어진 주차 번호의 단계(phase) 반환
  ///
  /// [weekNumber] 1부터 시작하는 주차 번호
  String phaseForWeek(int weekNumber) {
    if (weekNumber <= baseWeeks) return 'base';
    if (weekNumber <= baseWeeks + buildWeeks) return 'build';
    if (weekNumber <= baseWeeks + buildWeeks + peakWeeks) return 'peak';
    return 'taper';
  }

  Map<String, dynamic> toJson() => {
        'base_weeks': baseWeeks,
        'build_weeks': buildWeeks,
        'peak_weeks': peakWeeks,
        'taper_weeks': taperWeeks,
      };

  @override
  String toString() =>
      'Periodization(base: $baseWeeks, build: $buildWeeks, peak: $peakWeeks, taper: $taperWeeks)';
}
