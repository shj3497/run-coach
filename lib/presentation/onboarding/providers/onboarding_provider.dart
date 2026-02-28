import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/vdot_calculator.dart';
import '../../../data/models/race_record.dart';
import '../../../data/models/user_profile.dart';
import '../../../data/repositories/race_record_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/supabase_service.dart';
import '../../auth/providers/auth_providers.dart';
import 'onboarding_state.dart';

/// 온보딩 상태 관리 Notifier
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  final UserRepository _userRepo;
  final RaceRecordRepository _raceRecordRepo;
  final String? _userId;

  OnboardingNotifier({
    required UserRepository userRepo,
    required RaceRecordRepository raceRecordRepo,
    required String? userId,
  })  : _userRepo = userRepo,
        _raceRecordRepo = raceRecordRepo,
        _userId = userId,
        super(const OnboardingState());

  /// B-1: 프로필 저장
  Future<bool> saveProfile({
    required String nickname,
    String? gender,
    int? birthYear,
    double? heightCm,
    double? weightKg,
  }) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final now = DateTime.now();
      final profile = UserProfile(
        id: _userId,
        nickname: nickname,
        gender: gender,
        birthYear: birthYear,
        heightCm: heightCm,
        weightKg: weightKg,
        createdAt: now,
        updatedAt: now,
      );
      await _userRepo.upsertProfile(profile);
      state = state.copyWith(
        nickname: nickname,
        gender: gender,
        birthYear: birthYear,
        heightCm: heightCm,
        weightKg: weightKg,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '프로필 저장에 실패했습니다',
      );
      return false;
    }
  }

  /// B-2: 러닝 경험 저장
  Future<bool> saveExperience({
    required String runningExperience,
    required int weeklyAvailableDays,
  }) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      await _userRepo.updateProfile(_userId, {
        'running_experience': runningExperience,
        'weekly_available_days': weeklyAvailableDays,
      });
      state = state.copyWith(
        runningExperience: runningExperience,
        weeklyAvailableDays: weeklyAvailableDays,
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '러닝 경험 저장에 실패했습니다',
      );
      return false;
    }
  }

  /// B-3: 데이터 연동 상태 업데이트 (UI만)
  void setHealthKitConnected(bool connected) {
    state = state.copyWith(healthKitConnected: connected);
  }

  void setStravaConnected(bool connected) {
    state = state.copyWith(stravaConnected: connected);
  }

  /// B-4: 대회 기록 추가
  Future<bool> addRaceRecord({
    required String raceName,
    required DateTime raceDate,
    required double distanceKm,
    required int finishTimeSeconds,
  }) async {
    if (_userId == null) return false;

    state = state.copyWith(isLoading: true, error: null);
    try {
      final vdot = VdotCalculator.calculate(
        distanceKm: distanceKm,
        finishTimeSeconds: finishTimeSeconds,
      );

      final now = DateTime.now();
      final record = RaceRecord(
        id: '',
        userId: _userId,
        raceName: raceName,
        raceDate: raceDate,
        distanceKm: distanceKm,
        finishTimeSeconds: finishTimeSeconds,
        vdotScore: vdot,
        createdAt: now,
        updatedAt: now,
      );

      final saved = await _raceRecordRepo.addRecord(record);
      state = state.copyWith(
        raceRecords: [...state.raceRecords, saved],
        isLoading: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '대회 기록 저장에 실패했습니다',
      );
      return false;
    }
  }

  /// B-4: 대회 기록 삭제
  Future<void> removeRaceRecord(String recordId) async {
    try {
      await _raceRecordRepo.deleteRecord(recordId);
      state = state.copyWith(
        raceRecords:
            state.raceRecords.where((r) => r.id != recordId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: '기록 삭제에 실패했습니다');
    }
  }

  /// B-5: 목표 설정 업데이트 (로컬 상태)
  void updateGoal({
    String? goalRaceName,
    DateTime? goalRaceDate,
    double? goalDistanceKm,
    int? goalTimeSeconds,
    bool? justFinishGoal,
    int? trainingWeeks,
  }) {
    state = state.copyWith(
      goalRaceName: goalRaceName,
      goalRaceDate: goalRaceDate,
      goalDistanceKm: goalDistanceKm,
      goalTimeSeconds: goalTimeSeconds,
      justFinishGoal: justFinishGoal,
      trainingWeeks: trainingWeeks,
    );
  }

  /// B-5: 온보딩 완료
  Future<bool> completeOnboarding() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      // 선호 거리 업데이트
      if (_userId != null && state.goalDistanceKm != null) {
        String? distanceLabel;
        if (state.goalDistanceKm == 5.0) {
          distanceLabel = '5k';
        } else if (state.goalDistanceKm == 10.0) {
          distanceLabel = '10k';
        } else if (state.goalDistanceKm == 21.0975) {
          distanceLabel = 'half';
        } else if (state.goalDistanceKm == 42.195) {
          distanceLabel = 'full';
        }
        if (distanceLabel != null) {
          await _userRepo.updateProfile(_userId, {
            'preferred_distance': distanceLabel,
          });
        }
      }

      // 온보딩 완료 플래그 저장
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: '설정 완료에 실패했습니다',
      );
      return false;
    }
  }
}

/// 온보딩 Provider
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  final userRepo = ref.watch(userRepositoryProvider);
  final raceRecordRepo = RaceRecordRepository(SupabaseService.client);
  final user = ref.watch(currentUserProvider);

  return OnboardingNotifier(
    userRepo: userRepo,
    raceRecordRepo: raceRecordRepo,
    userId: user?.id,
  );
});
