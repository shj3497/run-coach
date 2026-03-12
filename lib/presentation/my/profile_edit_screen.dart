import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../auth/providers/auth_providers.dart';
import '../onboarding/widgets/day_selector.dart';
import '../onboarding/widgets/experience_card.dart';
import 'providers/my_page_provider.dart';

/// 프로필 수정 화면
class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});

  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  final _nicknameController = TextEditingController();
  String? _selectedExperience;
  int? _selectedDays;
  bool _isLoading = true;
  bool _isSaving = false;

  // 원본 값 (변경 감지용)
  String? _originalNickname;
  String? _originalExperience;
  int? _originalDays;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final userRepo = ref.read(userRepositoryProvider);
    final profile = await userRepo.getProfile(user.id);

    if (profile != null && mounted) {
      setState(() {
        _nicknameController.text = profile.nickname;
        _selectedExperience = profile.runningExperience;
        _selectedDays = profile.weeklyAvailableDays;
        _originalNickname = profile.nickname;
        _originalExperience = profile.runningExperience;
        _originalDays = profile.weeklyAvailableDays;
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  bool get _hasChanges {
    return _nicknameController.text != _originalNickname ||
        _selectedExperience != _originalExperience ||
        _selectedDays != _originalDays;
  }

  bool get _isValid {
    return _nicknameController.text.trim().isNotEmpty;
  }

  Future<void> _onSave() async {
    if (!_hasChanges || !_isValid || _isSaving) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final userRepo = ref.read(userRepositoryProvider);
      await userRepo.updateProfile(user.id, {
        'nickname': _nicknameController.text.trim(),
        'running_experience': _selectedExperience,
        'weekly_available_days': _selectedDays,
      });

      ref.invalidate(myPageProfileProvider);

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '저장 실패: $e',
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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '프로필 수정',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppSpacing.lg),

                    // 닉네임
                    Text(
                      '닉네임',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _nicknameController,
                      maxLength: 50,
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                      ),
                      decoration: InputDecoration(
                        hintText: '닉네임을 입력하세요',
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
                          borderRadius:
                              BorderRadius.circular(AppSpacing.badgeRadius),
                          borderSide:
                              BorderSide(color: AppColors.divider(context)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.badgeRadius),
                          borderSide:
                              BorderSide(color: AppColors.divider(context)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppSpacing.badgeRadius),
                          borderSide: BorderSide(
                            color: AppColors.primary(context),
                            width: 2,
                          ),
                        ),
                        counterStyle: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 러닝 경험
                    Text(
                      '러닝 경험',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ExperienceCard(
                      icon: '🏃',
                      title: '초보자',
                      description: '달리기 시작한 지 6개월 미만',
                      isSelected: _selectedExperience == 'beginner',
                      onTap: () =>
                          setState(() => _selectedExperience = 'beginner'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ExperienceCard(
                      icon: '🏃‍♂️',
                      title: '중급자',
                      description: '정기적으로 달리기 / 6개월 ~ 2년',
                      isSelected: _selectedExperience == 'intermediate',
                      onTap: () =>
                          setState(() => _selectedExperience = 'intermediate'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    ExperienceCard(
                      icon: '🏅',
                      title: '고급자',
                      description: '대회 참가 경험 / 2년 이상',
                      isSelected: _selectedExperience == 'advanced',
                      onTap: () =>
                          setState(() => _selectedExperience = 'advanced'),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // 주당 훈련일수
                    Text(
                      '주당 훈련일수',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textPrimary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    DaySelector(
                      selectedDays: _selectedDays,
                      onChanged: (days) =>
                          setState(() => _selectedDays = days),
                    ),

                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: _isLoading
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.screenPadding),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed:
                        _hasChanges && _isValid && !_isSaving ? _onSave : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary(context),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: AppColors.textDisabled(context),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            '저장',
                            style:
                                AppTypography.h3.copyWith(color: Colors.white),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}
