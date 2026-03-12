import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../presentation/auth/providers/auth_providers.dart';
import '../../presentation/providers/data_providers.dart';
import '../../presentation/providers/notification_provider.dart';

/// 알림이 활성화되어 있으면 활성 플랜 세션을 스케줄링한다.
/// 플랜 생성/활성화/전환 후 호출.
Future<void> scheduleNotificationsIfEnabled(WidgetRef ref) async {
  final settings = ref.read(notificationSettingsProvider);
  if (!settings.enabled) return;

  final service = ref.read(notificationServiceProvider);
  final user = ref.read(currentUserProvider);
  if (user == null) return;

  final planRepo = ref.read(planRepositoryProvider);
  final plan = await planRepo.getActivePlan(user.id);
  if (plan == null) {
    await service.cancelAll();
    return;
  }

  // 모든 세션 로드
  final weeks = await planRepo.getWeeksByPlan(plan.id);
  final allSessions = <dynamic>[];
  for (final week in weeks) {
    final sessions = await planRepo.getSessionsByWeek(week.id);
    allSessions.addAll(sessions);
  }

  // 기존 알림 제거 후 재스케줄
  await service.cancelAll();
  await service.scheduleForPlan(
    sessions: allSessions.cast(),
    hour: settings.hour,
    minute: settings.minute,
  );
}
