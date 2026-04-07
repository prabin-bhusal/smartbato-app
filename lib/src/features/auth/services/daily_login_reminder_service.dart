import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DailyLoginReminderService {
  DailyLoginReminderService._();

  static final DailyLoginReminderService instance =
      DailyLoginReminderService._();

  static const int _notificationId = 910001;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initializeAndSchedule() async {
    if (kIsWeb) {
      return;
    }

    await _initialize();
    await _scheduleDailyReminder();
  }

  Future<void> _initialize() async {
    if (_initialized) {
      return;
    }

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iOSInit);

    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<void> _scheduleDailyReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, 6);

    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }

    const androidDetails = AndroidNotificationDetails(
      'daily_login_reminders',
      'Daily Login Reminders',
      channelDescription: 'Daily reminder to login and claim coin rewards',
      importance: Importance.high,
      priority: Priority.high,
    );

    const iOSDetails = DarwinNotificationDetails();

    await _notifications.zonedSchedule(
      _notificationId,
      'Daily Reward Waiting',
      'Login now to claim your daily coin reward in SmartBato.',
      next,
      const NotificationDetails(android: androidDetails, iOS: iOSDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: 'daily_login_reward',
    );
  }
}
