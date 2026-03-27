import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_preferences.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Preferência de Ajustes: vibração nas notificações locais (Android: canal + detalhe).
  bool _vibrationEnabled = true;

  /// Últimos lembretes agendados (para reaplicar ao mudar vibração sem abrir a aba Alertas).
  NotificationPreferences? _cachedPrefsForReschedule;

  String _androidChannelNowId() =>
      _vibrationEnabled ? 'bebeu_water_now' : 'bebeu_water_now_nv';

  String _androidChannelScheduledId() => _vibrationEnabled
      ? 'bebeu_hydration_scheduled'
      : 'bebeu_hydration_scheduled_nv';

  Future<void> _syncAndroidChannels() async {
    if (kIsWeb) return;
    final android = _notificationsPlugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    final vib = _vibrationEnabled;
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _androidChannelNowId(),
        'Lembretes de Hidratação',
        description: 'Alertas na hora e meta do dia',
        importance: Importance.max,
        playSound: true,
        enableVibration: vib,
      ),
    );
    await android.createNotificationChannel(
      AndroidNotificationChannel(
        _androidChannelScheduledId(),
        'Lembretes programados',
        description: 'Horários que você definiu em Alertas',
        importance: Importance.high,
        playSound: true,
        enableVibration: vib,
      ),
    );
  }

  /// Chamar após carregar Ajustes ou quando o usuário altera o interruptor de vibração.
  Future<void> setVibrationEnabled(bool enabled) async {
    final vibrationChanged = _vibrationEnabled != enabled;
    _vibrationEnabled = enabled;
    await _syncAndroidChannels();
    if (vibrationChanged &&
        _cachedPrefsForReschedule != null &&
        _cachedPrefsForReschedule!.enabled) {
      await scheduleHydrationReminders(_cachedPrefsForReschedule!);
    }
  }

  Future<void> initialize() async {
    if (kIsWeb) return; // Silencia no Web onde o plugin não é suportado da mesma forma

    tz.initializeTimeZones();
    // Tenta configurar o local, se falhar usa UTC como fallback para evitar crash
    try {
      // Em apps reais, usaríamos o pacote flutter_timezone para pegar o local exato
      // Por enquanto, vamos garantir que tz.local não esteja vazio
      tz.setLocalLocation(tz.getLocation('America/Sao_Paulo'));
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/logo');

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

    await _notificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
      },
    );

    // Request notification permission on Android 13+
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      await _syncAndroidChannels();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return; // Não disponível no Web

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelNowId(),
        'Lembretes de Hidratação',
        channelDescription: 'Notificações para beber água',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        showWhen: true,
        enableVibration: _vibrationEnabled,
      ),
      iOS: const DarwinNotificationDetails(),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }

  Future<void> scheduleHydrationReminders(NotificationPreferences prefs) async {
    if (kIsWeb) return; // Não disponível no Web

    await _notificationsPlugin.cancelAll();
    _cachedPrefsForReschedule = prefs.enabled ? prefs : null;

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
      
      // Verifica se o dia da semana está ativo (DateTime.weekday: 1=Seg...7=Dom)
      if (!prefs.activeDays.contains(date.weekday)) continue;

      // Usando um intervalo seguro (mínimo 1 hora se vier 0 do cálculo atual)
      final step = prefs.intervalHours > 0 ? prefs.intervalHours : 1;

      for (int hour = startTime.hour; hour <= endTime.hour; hour += step) {
        final scheduleTime = DateTime(
          date.year,
          date.month,
          date.day,
          hour,
          startTime.minute,
        );

        if (scheduleTime.isAfter(now)) {
          await _notificationsPlugin.zonedSchedule(
            id: i * 100 + hour,
            title: 'Hora de beber água!',
            body: 'Mantenha seu corpo hidratado. Tome um copo d\'água agora.',
            scheduledDate: tz.TZDateTime.from(scheduleTime, tz.local),
            notificationDetails: NotificationDetails(
              android: AndroidNotificationDetails(
                _androidChannelScheduledId(),
                'Lembretes Periódicos',
                channelDescription: 'Lembretes para beber água ao longo do dia',
                importance: Importance.high,
                priority: Priority.high,
                visibility: NotificationVisibility.public,
                showWhen: true,
                enableVibration: _vibrationEnabled,
                playSound: true,
              ),
              iOS: const DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
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
