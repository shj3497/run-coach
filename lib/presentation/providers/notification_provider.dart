import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/notification_service.dart';

/// 알림 설정 상태
class NotificationSettings {
  final bool enabled;
  final int hour;
  final int minute;

  const NotificationSettings({
    this.enabled = false,
    this.hour = 8,
    this.minute = 0,
  });

  NotificationSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
  }) =>
      NotificationSettings(
        enabled: enabled ?? this.enabled,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
      );
}

/// 알림 설정 StateNotifier — SharedPreferences 영속화
class NotificationSettingsNotifier extends StateNotifier<NotificationSettings> {
  NotificationSettingsNotifier() : super(const NotificationSettings()) {
    _load();
  }

  static const _keyEnabled = 'notification_enabled';
  static const _keyHour = 'notification_hour';
  static const _keyMinute = 'notification_minute';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = NotificationSettings(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      hour: prefs.getInt(_keyHour) ?? 8,
      minute: prefs.getInt(_keyMinute) ?? 0,
    );
  }

  Future<void> setEnabled(bool value) async {
    state = state.copyWith(enabled: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  Future<void> setTime(int hour, int minute) async {
    state = state.copyWith(hour: hour, minute: minute);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyHour, hour);
    await prefs.setInt(_keyMinute, minute);
  }
}

/// 알림 설정 Provider
final notificationSettingsProvider =
    StateNotifierProvider<NotificationSettingsNotifier, NotificationSettings>(
  (ref) => NotificationSettingsNotifier(),
);

/// NotificationService 싱글톤 Provider
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
