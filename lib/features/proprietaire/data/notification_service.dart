import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/rappel.dart';

class NotificationService {
  NotificationService._();

  static final instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    final zoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zoneName));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
  }

  Future<void> rescheduleAll(
    Iterable<({Rappel rappel, String motoNom})> reminders,
  ) async {
    await _plugin.cancelAll();
    for (final entry in reminders) {
      final now = DateTime.now();
      var scheduledDate = DateTime(
        entry.rappel.date.year,
        entry.rappel.date.month,
        entry.rappel.date.day,
        9,
      );
      if (!scheduledDate.isAfter(now) &&
          entry.rappel.date.year == now.year &&
          entry.rappel.date.month == now.month &&
          entry.rappel.date.day == now.day) {
        scheduledDate = now.add(const Duration(minutes: 1));
      }
      await scheduleReminder(
        id: entry.rappel.notificationId ?? notificationIdFor(entry.rappel.id),
        title: entry.rappel.titre,
        body: 'Un rappel d’entretien est prévu aujourd’hui pour ${entry.motoNom}.',
        date: scheduledDate,
      );
    }
  }

  Future<bool> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime date,
  }) async {
    if (!date.isAfter(DateTime.now())) return false;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tz.TZDateTime.from(date, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'entretien_moto',
          'Rappels d’entretien',
          channelDescription: 'Notifications pour les échéances d’entretien.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    return true;
  }

  Future<void> cancelReminder(int id) => _plugin.cancel(id);
}
