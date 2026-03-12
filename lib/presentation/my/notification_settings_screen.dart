import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/app_typography.dart';
import '../../domain/usecases/schedule_notifications.dart';
import '../providers/notification_provider.dart';

/// 알림 설정 화면
class NotificationSettingsScreen extends ConsumerWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(notificationSettingsProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(
          '알림 설정',
          style: AppTypography.h3.copyWith(
            color: AppColors.textPrimary(context),
          ),
        ),
        backgroundColor: AppColors.background(context),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.lg),

            // 알림 on/off
            _buildSection(context, children: [
              _buildRow(
                context,
                label: '훈련 리마인더',
                trailing: Switch.adaptive(
                  value: settings.enabled,
                  activeTrackColor: AppColors.primary(context),
                  onChanged: (value) =>
                      _onToggle(context, ref, value),
                ),
              ),
            ]),

            const SizedBox(height: AppSpacing.lg),

            // 알림 시간
            if (settings.enabled) ...[
              _buildSection(context, children: [
                _buildRow(
                  context,
                  label: '알림 시간',
                  trailing: GestureDetector(
                    onTap: () => _showTimePicker(context, ref, settings),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(settings.hour, settings.minute),
                          style: AppTypography.body.copyWith(
                            color: AppColors.primary(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ]),

              const SizedBox(height: AppSpacing.lg),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding + AppSpacing.sm,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '설정한 시간에 오늘의 훈련 내용을 알려드립니다.',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _onToggle(
    BuildContext context,
    WidgetRef ref,
    bool enabled,
  ) async {
    final notifier = ref.read(notificationSettingsProvider.notifier);
    final service = ref.read(notificationServiceProvider);

    if (enabled) {
      final granted = await service.requestPermission();
      if (!granted) return;
      await notifier.setEnabled(true);
      // 활성 플랜 세션 스케줄링
      await scheduleNotificationsIfEnabled(ref);
    } else {
      await notifier.setEnabled(false);
      await service.cancelAll();
    }
  }

  void _showTimePicker(
    BuildContext context,
    WidgetRef ref,
    NotificationSettings settings,
  ) {
    var selectedHour = settings.hour;
    var selectedMinute = settings.minute;

    showCupertinoModalPopup(
      context: context,
      builder: (popupContext) => Container(
        height: 280,
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppSpacing.cardRadius),
          ),
        ),
        child: Column(
          children: [
            // 헤더
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenPadding,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      '취소',
                      style: AppTypography.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onPressed: () => Navigator.of(popupContext).pop(),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: Text(
                      '완료',
                      style: AppTypography.body.copyWith(
                        color: AppColors.primary(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () async {
                      Navigator.of(popupContext).pop();
                      final notifier =
                          ref.read(notificationSettingsProvider.notifier);
                      await notifier.setTime(selectedHour, selectedMinute);
                      // 재스케줄링
                      await scheduleNotificationsIfEnabled(ref);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 0.5),
            // 타임피커
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: DateTime(
                  2024, 1, 1,
                  settings.hour,
                  settings.minute,
                ),
                onDateTimeChanged: (dateTime) {
                  selectedHour = dateTime.hour;
                  selectedMinute = dateTime.minute;
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final period = hour < 12 ? '오전' : '오후';
    final h = hour <= 12 ? hour : hour - 12;
    final displayHour = h == 0 ? 12 : h;
    return '$period $displayHour:${minute.toString().padLeft(2, '0')}';
  }

  Widget _buildSection(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenPadding,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        ),
        child: Column(children: children),
      ),
    );
  }

  Widget _buildRow(
    BuildContext context, {
    required String label,
    required Widget trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: 14,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary(context),
              ),
            ),
          ),
          trailing,
        ],
      ),
    );
  }
}
