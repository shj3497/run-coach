import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../../core/constants/training_zones.dart';
import '../models/training_session.dart';

/// 로컬 알림 서비스 (싱글톤)
class NotificationService {
  NotificationService._();
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// 초기화 (main.dart에서 호출)
  Future<void> initialize() async {
    if (_initialized) return;

    // timezone 초기화
    tz_data.initializeTimeZones();
    final timezoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneName));

    // 플러그인 초기화
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(iOS: darwinSettings);
    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  /// iOS 알림 권한 요청
  Future<bool> requestPermission() async {
    final result = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    return result ?? false;
  }

  /// 단일 알림 스케줄링
  Future<void> scheduleTrainingReminder({
    required int id,
    required String title,
    required String body,
    required DateTime date,
    required int hour,
    required int minute,
  }) async {
    final scheduledDate = tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );

    // 과거 시간이면 스킵
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledDate,
      const NotificationDetails(iOS: darwinDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 플랜 전체 세션 알림 스케줄링
  ///
  /// pending + 미래 날짜 + rest 제외 세션만 스케줄.
  /// iOS 64개 제한 대응: 최대 60개만 스케줄 (가까운 날짜 우선)
  Future<void> scheduleForPlan({
    required List<TrainingSession> sessions,
    required int hour,
    required int minute,
  }) async {
    // 필터: pending + 미래 + rest 제외
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eligible = sessions.where((s) {
      if (s.status != 'pending') return false;
      if (s.sessionDate.isBefore(today)) return false;
      if (s.sessionType == 'rest') return false;
      return true;
    }).toList();

    // 날짜순 정렬 → 가까운 60개만
    eligible.sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    final toSchedule = eligible.take(60).toList();

    for (int i = 0; i < toSchedule.length; i++) {
      final session = toSchedule[i];
      final zoneType = trainingZoneTypeFromDbString(session.sessionType);
      final zone = TrainingZones.fromType(zoneType);
      final distanceStr = session.targetDistanceKm != null
          ? ' ${session.targetDistanceKm!.toStringAsFixed(0)}km'
          : '';

      await scheduleTrainingReminder(
        id: i + 1, // 1부터 시작
        title: '오늘의 훈련',
        body: '오늘은 ${zone.label}$distanceStr 날이에요',
        date: session.sessionDate,
        hour: hour,
        minute: minute,
      );
    }
  }

  /// 플랜 알림 취소 (전체 취소 후 재스케줄 방식 사용)
  Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
