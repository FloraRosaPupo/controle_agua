import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import '../models/notification_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'water_reminders',
      'Lembretes de Hidratação',
      channelDescription: 'Notificações para beber água',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(id, title, body, details);
  }

  Future<void> scheduleHydrationReminders(NotificationPreferences prefs) async {
    await _notificationsPlugin.cancelAll();

    if (!prefs.enabled) return;

    final now = DateTime.now();
    final startParts = prefs.startTime.split(':');
    final endParts = prefs.endTime.split(':');

    final startTime = TimeOfDay(
      hour: int.parse(startParts[0]),
      minute: int.parse(startParts[1]),
    );
    final endTime = TimeOfDay(
      hour: int.parse(endParts[0]),
      minute: int.parse(endParts[1]),
    );

    // Agendar notificações para os próximos 7 dias
    for (int i = 0; i < 7; i++) {
      final date = now.add(Duration(days: i));
      
      // Verifica se o dia da semana está ativo (Prisma/JS: 0=Dom, 1=Seg...)
      // Mas o usuário usou 1=Seg...7=Dom no plano. Vamos converter:
      // DateTime.weekday: 1=Seg, 7=Dom.
      if (!prefs.activeDays.contains(date.weekday)) continue;

      for (int hour = startTime.hour; hour <= endTime.hour; hour += prefs.intervalHours) {
        final scheduleTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          startTime.minute,
        );

        if (scheduleTime.isAfter(now)) {
          await _notificationsPlugin.zonedSchedule(
            i * 100 + hour,
            'Hora de beber água!',
            'Mantenha seu corpo hidratado. Tome um copo d\'água agora.',
            tz.TZDateTime.from(scheduleTime, tz.local),
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'hydration_reminders',
                'Lembretes Periódicos',
                importance: Importance.low,
              ),
            ),
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            matchDateTimeComponents: DateTimeComponents.time,
          );
        }
      }
    }
  }

  void checkProgressAndNotify({
    required int current,
    required int goal,
    required String userName,
  }) {
    if (goal <= 0) return;

    final percent = (current / goal) * 100;
    final remaining = goal - current;

    if (current >= goal) {
      showNotification(
        id: 999,
        title: 'Meta Atingida!',
        body: 'Parabéns, $userName! Você atingiu sua meta diária de ${goal}ml!',
      );
    } else if (percent >= 80) {
      showNotification(
        id: 998,
        title: 'Quase lá!',
        body: 'Falta muito pouco! Apenas ${remaining}ml para atingir sua meta.',
      );
    }
  }
}
