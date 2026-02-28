import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import 'providers/onboarding_provider.dart';

/// B-1: 프로필 입력 화면
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _nicknameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  String? _gender;
  int? _birthYear;

  @override
  void dispose() {
    _nicknameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  bool get _isValid => _nicknameController.text.trim().isNotEmpty;

  Future<void> _onNext() async {
    final notifier = ref.read(onboardingProvider.notifier);
    final success = await notifier.saveProfile(
      nickname: _nicknameController.text.trim(),
      gender: _gender,
      birthYear: _birthYear,
      heightCm: double.tryParse(_heightController.text),
      weightKg: double.tryParse(_weightController.text),
    );
    if (success && mounted) {
      context.go('/onboarding/experience');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '1/5',
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        backgroundColor: AppColors.background(context),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/login'),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.lg),
              Text(
                '반갑습니다!',
                style: AppTypography.h1.copyWith(
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '프로필을 설정해주세요',
                style: AppTypography.bodyLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 닉네임 (필수)
              _buildLabel('닉네임', required: true),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _nicknameController,
                style: AppTypography.body.copyWith(
                  color: AppColors.textPrimary(context),
                ),
                maxLength: 50,
                decoration: _inputDecoration(context, '닉네임을 입력해주세요'),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 성별 (선택)
              _buildLabel('성별'),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: ['남성', '여성', '미설정'].map((label) {
                  final value = label == '미설정' ? null : label;
                  final isSelected = _gender == value;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () => setState(() => _gender = value),
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary(context)
                                : AppColors.surface(context),
                            borderRadius: BorderRadius.circular(
                              AppSpacing.badgeRadius,
                            ),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary(context)
                                  : AppColors.divider(context),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            label,
                            style: AppTypography.body.copyWith(
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.textPrimary(context),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 출생 연도 (선택)
              _buildLabel('출생 연도'),
              const SizedBox(height: AppSpacing.sm),
              GestureDetector(
                onTap: () => _showYearPicker(context),
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
                  child: Text(
                    _birthYear != null ? '$_birthYear년' : '선택',
                    style: AppTypography.body.copyWith(
                      color: _birthYear != null
                          ? AppColors.textPrimary(context)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // 키 (선택)
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('키'),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _heightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary(context),
                          ),
                          decoration: _inputDecoration(context, 'cm'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  // 체중 (선택)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('체중'),
                        const SizedBox(height: AppSpacing.sm),
                        TextField(
                          controller: _weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: AppTypography.body.copyWith(
                            color: AppColors.textPrimary(context),
                          ),
                          decoration: _inputDecoration(context, 'kg'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              // 에러 메시지
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                  child: Text(
                    state.error!,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isValid && !state.isLoading ? _onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary(context),
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.textDisabled(context),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppSpacing.buttonRadius),
                ),
              ),
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      '다음',
                      style: AppTypography.h3.copyWith(color: Colors.white),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String label, {bool required = false}) {
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
      counterText: '',
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

  void _showYearPicker(BuildContext context) {
    final currentYear = DateTime.now().year;
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SizedBox(
          height: 300,
          child: ListView.builder(
            itemCount: currentYear - 1939,
            itemBuilder: (ctx, index) {
              final year = currentYear - index;
              return ListTile(
                title: Text(
                  '$year년',
                  style: AppTypography.body.copyWith(
                    color: AppColors.textPrimary(context),
                    fontWeight:
                        year == _birthYear ? FontWeight.bold : null,
                  ),
                ),
                selected: year == _birthYear,
                onTap: () {
                  setState(() => _birthYear = year);
                  Navigator.pop(ctx);
                },
              );
            },
          ),
        );
      },
    );
  }
}
