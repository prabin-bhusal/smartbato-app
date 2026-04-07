import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../../dashboard/models/analytics_data.dart';

class LiveTestReminderService {
  LiveTestReminderService._();

  static final LiveTestReminderService instance = LiveTestReminderService._();

  static const String _enrollmentKey = 'live_test_enrollments_v1';
  static const String _attemptedKey = 'live_test_attempted_v1';
  static const int _groupBase = 730000;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) {
      return;
    }

    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSInit = DarwinInitializationSettings();
    const settings = InitializationSettings(android: androidInit, iOS: iOSInit);

    await _notifications.initialize(settings);
    _initialized = true;
  }

  Future<Set<int>> getEnrolledTestIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_enrollmentKey);
    if (raw == null || raw.isEmpty) {
      return <int>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <int>{};
    }

    return decoded.map((item) => _asInt(item)).where((id) => id > 0).toSet();
  }

  Future<void> enrollAndSchedule(AnalyticsLiveTest test) async {
    await initialize();

    final ids = await getEnrolledTestIds();
    ids.add(test.stableId);
    await _saveIds(ids);

    final start = test.startsAt;
    if (start == null || kIsWeb) {
      return;
    }

    await _scheduleReminder(
      test: test,
      reminderId: _notificationId(test.stableId, 1),
      target: start.subtract(const Duration(hours: 1)),
      title: 'Live Test in 1 hour',
      body: '${test.name} starts in 1 hour. Be ready to join.',
    );

    await _scheduleReminder(
      test: test,
      reminderId: _notificationId(test.stableId, 2),
      target: start.subtract(const Duration(minutes: 30)),
      title: 'Live Test in 30 minutes',
      body: '${test.name} starts in 30 minutes. Keep your app ready.',
    );

    await _scheduleReminder(
      test: test,
      reminderId: _notificationId(test.stableId, 3),
      target: start.subtract(const Duration(minutes: 5)),
      title: 'Live Test in 5 minutes',
      body: '${test.name} is almost live. Join soon.',
    );
  }

  Future<void> syncEnrolledTests({
    required List<AnalyticsLiveTest> tests,
    required Set<int> enrolledServerIds,
  }) async {
    final localIds = tests
        .where((test) => test.id > 0 && enrolledServerIds.contains(test.id))
        .map((test) => test.stableId)
        .toSet();

    await _saveIds(localIds);
  }

  Future<Set<int>> getAttemptedTestIds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_attemptedKey);
    if (raw == null || raw.isEmpty) {
      return <int>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <int>{};
    }

    return decoded.map((item) => _asInt(item)).where((id) => id > 0).toSet();
  }

  Future<void> markAttempted(AnalyticsLiveTest test) async {
    final ids = await getAttemptedTestIds();
    ids.add(test.stableId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_attemptedKey, jsonEncode(ids.toList()..sort()));
  }

  Future<void> clearEnrollment(AnalyticsLiveTest test) async {
    final ids = await getEnrolledTestIds();
    ids.remove(test.stableId);
    await _saveIds(ids);

    if (kIsWeb) {
      return;
    }

    await _notifications.cancel(_notificationId(test.stableId, 1));
    await _notifications.cancel(_notificationId(test.stableId, 2));
    await _notifications.cancel(_notificationId(test.stableId, 3));
  }

  Future<void> _scheduleReminder({
    required AnalyticsLiveTest test,
    required int reminderId,
    required DateTime target,
    required String title,
    required String body,
  }) async {
    if (target.isBefore(DateTime.now())) {
      return;
    }

    const androidDetails = AndroidNotificationDetails(
      'live_test_reminders',
      'Live Test Reminders',
      channelDescription: 'Reminder notifications for enrolled live tests',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iOSDetails = DarwinNotificationDetails();

    try {
      await _notifications.zonedSchedule(
        reminderId,
        title,
        body,
        tz.TZDateTime.from(target.toUtc(), tz.UTC),
        const NotificationDetails(android: androidDetails, iOS: iOSDetails),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'live_test:${test.stableId}',
      );
    } on PlatformException catch (error) {
      final code = error.code.toLowerCase();
      final exactAlarmDenied =
          code.contains('exact_alaram_not_permitted') ||
          code.contains('exact_alarm_not_permitted') ||
          code.contains('exactalarm');

      if (!exactAlarmDenied) {
        rethrow;
      }

      await _notifications.zonedSchedule(
        reminderId,
        title,
        body,
        tz.TZDateTime.from(target.toUtc(), tz.UTC),
        const NotificationDetails(android: androidDetails, iOS: iOSDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'live_test:${test.stableId}',
      );
    }
  }

  Future<void> _saveIds(Set<int> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_enrollmentKey, jsonEncode(ids.toList()..sort()));
  }

  int _notificationId(int testId, int offset) =>
      _groupBase + (testId * 10) + offset;

  int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
