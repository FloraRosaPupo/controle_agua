import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/notification_preferences.dart';

/// Um par (dia da semana [DateTime.weekday], minutos desde 00:00) para agendar.
class _HydrationSlot {
  const _HydrationSlot(this.weekday, this.totalMinutes);
  final int weekday;
  final int totalMinutes;
}

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

  /// Evita duas sequências cancelAll + zonedSchedule em paralelo (pode inflar alarmes no Android).
  Future<void> _scheduleChain = Future<void>.value();

  Timer? _debugNearFireTimer;

  String _androidChannelNowId() =>
      _vibrationEnabled ? 'bebeu_water_now' : 'bebeu_water_now_nv';

  String _androidChannelScheduledId() => _vibrationEnabled
      ? 'bebeu_hydration_scheduled'
      : 'bebeu_hydration_scheduled_nv';

  Future<void> _syncAndroidChannels() async {
    if (kIsWeb) return;
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
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
        importance: Importance.max,
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
    if (kIsWeb) {
      return; // Silencia no Web onde o plugin não é suportado da mesma forma
    }

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
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
      // Alarmes agendados: inexact costuma não disparar no horário com Doze / Android 14+.
      await androidPlugin.requestExactAlarmsPermission();
      await _syncAndroidChannels();
    }
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;

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

  Future<void> showProgressNotification({
    required int id,
    required String title,
    required int currentMl,
    required int goalMl,
    required int percent,
    required String statusText,
    bool ongoing = false,
  }) async {
    if (kIsWeb) return;

    final remaining = goalMl - currentMl;
    final clampedPercent = percent.clamp(0, 100);

    final String bodyText;
    if (remaining > 0) {
      bodyText = '$statusText • Faltam ${remaining}ml';
    } else {
      bodyText = statusText;
    }

    final details = NotificationDetails(
      android: AndroidNotificationDetails(
        _androidChannelNowId(),
        'Progresso de Hidratação',
        channelDescription: 'Acompanhe seu progresso de hidratação',
        importance: Importance.max,
        priority: Priority.high,
        visibility: NotificationVisibility.public,
        showWhen: true,
        enableVibration: _vibrationEnabled,
        subText: '$clampedPercent%',
        showProgress: true,
        maxProgress: 100,
        progress: clampedPercent,
        ongoing: ongoing,
        autoCancel: !ongoing,
      ),
      iOS: DarwinNotificationDetails(subtitle: '$clampedPercent% da meta'),
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: bodyText,
      notificationDetails: details,
    );
  }

  /// Próxima ocorrência semanal: [weekday] (1=Seg…7=Dom, como [DateTime.weekday]) às [hour]:[minute].
  tz.TZDateTime _nextWeekdayOccurrence(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    var days = weekday - t.weekday;
    if (days < 0) days += 7;
    t = t.add(Duration(days: days));
    if (!t.isAfter(now)) {
      t = t.add(const Duration(days: 7));
    }
    return t;
  }

  /// Próximo disparo no relógio (hora:minuto), repetindo **todo dia** (`DateTimeComponents.time`).
  tz.TZDateTime _nextDailyClockTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!t.isAfter(now)) {
      t = t.add(const Duration(days: 1));
    }
    return t;
  }

  static const Set<int> _allWeekdays = {1, 2, 3, 4, 5, 6, 7};

  /// Mínimo 30 min (igual às opções do app); evita intervalos antigos 1/5/15 vindos do servidor.
  int _scheduleStepMinutes(NotificationPreferences prefs) {
    final raw = prefs.intervalMinutes > 0 ? prefs.intervalMinutes : 60;
    return raw < 30 ? 30 : raw;
  }

  bool _activeDaysAreFullWeek(List<int> activeDays) {
    return activeDays.toSet().containsAll(_allWeekdays);
  }

  /// Marcas em minutos desde 00:00 dentro da janela, com passo fixo ou poucos pontos espaçados se passar [maxMarks].
  List<int> _minuteMarksInWindow({
    required int startTotalMinutes,
    required int endTotalMinutes,
    required int stepMinutes,
    required int maxMarks,
  }) {
    if (endTotalMinutes < startTotalMinutes) return [];
    var nSteps = 0;
    for (var t = startTotalMinutes; t <= endTotalMinutes; t += stepMinutes) {
      nSteps++;
    }
    if (nSteps <= maxMarks) {
      return [
        for (var t = startTotalMinutes; t <= endTotalMinutes; t += stepMinutes)
          t,
      ];
    }
    if (maxMarks <= 1) {
      return [startTotalMinutes];
    }
    final span = endTotalMinutes - startTotalMinutes;
    final seen = <int>{};
    final out = <int>[];
    for (var i = 0; i < maxMarks; i++) {
      final total =
          startTotalMinutes +
          ((span * i) / (maxMarks - 1)).round().clamp(0, span);
      if (seen.add(total)) {
        out.add(total);
      }
    }
    return out;
  }

  List<_HydrationSlot> _hydrationSlotsEvenPerDay(
    List<int> active,
    int startTotalMinutes,
    int endTotalMinutes,
    int maxAlarms,
  ) {
    final perDay = math.max(1, maxAlarms ~/ active.length);
    final span = endTotalMinutes - startTotalMinutes;
    final out = <_HydrationSlot>[];
    for (final weekday in active) {
      if (perDay == 1) {
        out.add(_HydrationSlot(weekday, startTotalMinutes));
        continue;
      }
      final seen = <int>{};
      for (var i = 0; i < perDay; i++) {
        final total =
            startTotalMinutes +
            ((span * i) / (perDay - 1)).round().clamp(0, span);
        if (seen.add(total)) {
          out.add(_HydrationSlot(weekday, total));
        }
      }
    }
    if (out.length > maxAlarms) {
      return out.sublist(0, maxAlarms);
    }
    return out;
  }

  List<_HydrationSlot> _hydrationSlotsUnified(
    NotificationPreferences prefs, {
    required int maxAlarms,
    required int startTotalMinutes,
    required int endTotalMinutes,
    required int stepMinutes,
  }) {
    final active = prefs.activeDays;
    if (active.isEmpty || endTotalMinutes < startTotalMinutes) return [];

    var nSteps = 0;
    for (var t = startTotalMinutes; t <= endTotalMinutes; t += stepMinutes) {
      nSteps++;
    }
    final totalWould = active.length * nSteps;

    if (totalWould <= maxAlarms) {
      final out = <_HydrationSlot>[];
      for (final weekday in active) {
        for (
          var t = startTotalMinutes;
          t <= endTotalMinutes;
          t += stepMinutes
        ) {
          out.add(_HydrationSlot(weekday, t));
        }
      }
      return out;
    }

    return _hydrationSlotsEvenPerDay(
      active,
      startTotalMinutes,
      endTotalMinutes,
      maxAlarms,
    );
  }

  List<tz.TZDateTime> _plannedNextFireTimes(
    NotificationPreferences prefs, {
    int maxPoints = 420,
  }) {
    if (!prefs.enabled || prefs.activeDays.isEmpty) return [];

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

    final stepMinutes = _scheduleStepMinutes(prefs);
    final startTotalMinutes = startTime.hour * 60 + startTime.minute;
    final endTotalMinutes = endTime.hour * 60 + endTime.minute;

    final list = <tz.TZDateTime>[];

    if (_activeDaysAreFullWeek(prefs.activeDays)) {
      final marks = _minuteMarksInWindow(
        startTotalMinutes: startTotalMinutes,
        endTotalMinutes: endTotalMinutes,
        stepMinutes: stepMinutes,
        maxMarks: maxPoints,
      );
      for (final total in marks) {
        final hour = total ~/ 60;
        final minute = total % 60;
        list.add(_nextDailyClockTime(hour, minute));
      }
    } else {
      final slots = _hydrationSlotsUnified(
        prefs,
        maxAlarms: maxPoints,
        startTotalMinutes: startTotalMinutes,
        endTotalMinutes: endTotalMinutes,
        stepMinutes: stepMinutes,
      );
      for (final s in slots) {
        final hour = s.totalMinutes ~/ 60;
        final minute = s.totalMinutes % 60;
        list.add(_nextWeekdayOccurrence(s.weekday, hour, minute));
      }
    }
    list.sort((a, b) => a.compareTo(b));
    return list;
  }

  void _stopDebugNearFireMonitoring() {
    _debugNearFireTimer?.cancel();
    _debugNearFireTimer = null;
  }

  void _startDebugNearFireMonitoring() {
    _stopDebugNearFireMonitoring();
    if (!kDebugMode || kIsWeb) return;

    _debugNearFireTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      final prefs = _cachedPrefsForReschedule;
      if (prefs == null || !prefs.enabled) {
        _stopDebugNearFireMonitoring();
        return;
      }

      final now = tz.TZDateTime.now(tz.local);
      final times = _plannedNextFireTimes(prefs);
      if (times.isEmpty) return;

      tz.TZDateTime? next;
      for (final t in times) {
        if (t.isAfter(now)) {
          next = t;
          break;
        }
      }
      next ??= times.first;

      final until = next.difference(now);
      if (until.inMinutes <= 5 && !until.isNegative) {
        debugPrint(
          '[BebeuNotify DEBUG] Próximo lembrete em ${until.inMinutes}m ${until.inSeconds % 60}s '
          '(local ${next.toString()}) | tz=${tz.local.name}',
        );
      }
    });
  }

  void _debugLogScheduleSummary(
    int scheduledCount,
    NotificationPreferences prefs,
  ) {
    if (!kDebugMode || kIsWeb) return;
    final times = _plannedNextFireTimes(prefs, maxPoints: scheduledCount);
    final modo = _activeDaysAreFullWeek(prefs.activeDays)
        ? 'diário (hora)'
        : 'dias da semana';
    final buf = StringBuffer(
      '[BebeuNotify DEBUG] Agendados $scheduledCount lembretes | modo=$modo | tz=${tz.local.name} | '
      'intervalo=${_scheduleStepMinutes(prefs)}m | ${prefs.startTime}–${prefs.endTime} | '
      'dias=${prefs.activeDays}',
    );
    if (times.isNotEmpty) {
      final show = times.length > 3 ? times.sublist(0, 3) : times;
      buf.write(' | próximos: ');
      buf.write(show.map((t) => t.toString()).join(', '));
      if (times.length > 3) buf.write(', …');
    }
    debugPrint(buf.toString());
  }

  Future<void> scheduleHydrationReminders(NotificationPreferences prefs) async {
    if (kIsWeb) return;

    _scheduleChain = _scheduleChain
        .catchError((Object e, StackTrace st) {
          debugPrint(
            'scheduleHydrationReminders: tentativa anterior falhou (fila segue): $e',
          );
        })
        .then((_) => _scheduleHydrationRemindersImpl(prefs));
    await _scheduleChain;
  }

  static const List<String> _reminderMessages = [
    'Hora de beber água! Mantenha seu corpo hidratado.',
    'Beba um copo d\'água agora! Se cuida.',
    'Não esqueça da sua meta! Um pequeno gole faz diferença.',
    'Hidratação é saúde! Que tal um pouco d\'água agora?',
    'Água é vida! Vamos bater a meta de hoje?',
  ];

  Future<void> _scheduleHydrationRemindersImpl(
    NotificationPreferences prefs,
  ) async {
    await _notificationsPlugin.cancelAll();
    _cachedPrefsForReschedule = prefs.enabled ? prefs : null;

    if (!prefs.enabled) {
      _stopDebugNearFireMonitoring();
      return;
    }

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

    int scheduledCount = 0;
    // Android: limite duro ~500 alarmes por app; margem para outros usos do plugin/OS.
    const int maxAlarms = 420;

    final stepMinutes = _scheduleStepMinutes(prefs);

    final startTotalMinutes = startTime.hour * 60 + startTime.minute;
    final endTotalMinutes = endTime.hour * 60 + endTime.minute;

    AndroidScheduleMode androidScheduleMode =
        AndroidScheduleMode.exactAllowWhileIdle;
    if (!kIsWeb) {
      final android = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final canExact = await android?.canScheduleExactNotifications();
      if (canExact != true) {
        androidScheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        debugPrint(
          '[BebeuNotify] Sem permissão de alarmes exatos — lembretes podem atrasar. '
          'Em Ajustes do Android: Apps > bebeu > Alarmes e lembretes (ou tempo) > permitir.',
        );
      }
    }

    if (_activeDaysAreFullWeek(prefs.activeDays)) {
      final marks = _minuteMarksInWindow(
        startTotalMinutes: startTotalMinutes,
        endTotalMinutes: endTotalMinutes,
        stepMinutes: stepMinutes,
        maxMarks: maxAlarms,
      );
      int messageIndex = 0;
      for (final total in marks) {
        final hour = total ~/ 60;
        final minute = total % 60;
        final message =
            _reminderMessages[messageIndex % _reminderMessages.length];
        messageIndex++;
        scheduledCount++;
        await _notificationsPlugin.zonedSchedule(
          id: total,
          title: 'Bebeu?',
          body: message,
          scheduledDate: _nextDailyClockTime(hour, minute),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelScheduledId(),
              'Lembretes Periódicos',
              channelDescription: 'Lembretes para beber água ao longo do dia',
              importance: Importance.max,
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
          androidScheduleMode: androidScheduleMode,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } else {
      final slots = _hydrationSlotsUnified(
        prefs,
        maxAlarms: maxAlarms,
        startTotalMinutes: startTotalMinutes,
        endTotalMinutes: endTotalMinutes,
        stepMinutes: stepMinutes,
      );
      int messageIndex = 0;
      for (final s in slots) {
        final hour = s.totalMinutes ~/ 60;
        final minute = s.totalMinutes % 60;
        final message =
            _reminderMessages[messageIndex % _reminderMessages.length];
        messageIndex++;
        scheduledCount++;
        await _notificationsPlugin.zonedSchedule(
          id: s.weekday * 1440 + s.totalMinutes,
          title: 'Bebeu?',
          body: message,
          scheduledDate: _nextWeekdayOccurrence(s.weekday, hour, minute),
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _androidChannelScheduledId(),
              'Lembretes Periódicos',
              channelDescription: 'Lembretes para beber água ao longo do dia',
              importance: Importance.max,
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
          androidScheduleMode: androidScheduleMode,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        );
      }
    }

    _debugLogScheduleSummary(scheduledCount, prefs);
    _startDebugNearFireMonitoring();
  }

  final Set<int> _notifiedMilestones = {};
  Timer? _progressReminderTimer;

  int? _lastCurrent;
  int? _lastGoal;
  String? _lastUserName;

  void checkProgressAndNotify({
    required int current,
    required int goal,
    required String userName,
  }) {
    if (goal <= 0) return;

    final percent = ((current / goal) * 100).toInt();

    _lastCurrent = current;
    _lastGoal = goal;
    _lastUserName = userName;

    if (current >= goal && !_notifiedMilestones.contains(100)) {
      _notifiedMilestones.add(100);
      _stopProgressReminder();
      _notificationsPlugin.cancel(id: 996);
      showProgressNotification(
        id: 999,
        title: '🎉 Meta atingida, $userName!',
        currentMl: current,
        goalMl: goal,
        percent: percent.clamp(0, 100),
        statusText: 'Parabéns! Você completou sua meta de ${goal}ml',
        ongoing: false,
      );
    } else if (percent >= 80 && !_notifiedMilestones.contains(80)) {
      _notifiedMilestones.add(80);
      _startProgressReminder();
      showProgressNotification(
        id: 996,
        title: '💧 Quase lá, $userName!',
        currentMl: current,
        goalMl: goal,
        percent: percent,
        statusText: 'Continue assim',
        ongoing: false,
      );
    } else if (percent >= 70 && !_notifiedMilestones.contains(70)) {
      _notifiedMilestones.add(70);
      _startProgressReminder();
      showProgressNotification(
        id: 996,
        title: '👏 Bom progresso, $userName!',
        currentMl: current,
        goalMl: goal,
        percent: percent,
        statusText: 'Você está no caminho certo',
        ongoing: false,
      );
    }
  }

  void _startProgressReminder() {
    _stopProgressReminder();
    _progressReminderTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _reshowProgressNotification(),
    );
  }

  void _stopProgressReminder() {
    _progressReminderTimer?.cancel();
    _progressReminderTimer = null;
  }

  void _reshowProgressNotification() {
    if (_lastCurrent == null || _lastGoal == null || _lastUserName == null)
      return;
    if (_notifiedMilestones.contains(100)) return;

    final percent = ((_lastCurrent! / _lastGoal!) * 100).toInt();
    if (percent < 70) return;

    final String title;
    final String statusText;

    if (percent >= 80) {
      title = '💧 Quase lá, $_lastUserName!';
      statusText = 'Continue assim';
    } else {
      title = '👏 Bom progresso, $_lastUserName!';
      statusText = 'Você está no caminho certo';
    }

    showProgressNotification(
      id: 996,
      title: title,
      currentMl: _lastCurrent!,
      goalMl: _lastGoal!,
      percent: percent,
      statusText: statusText,
      ongoing: false,
    );
  }

  void resetDailyMilestones() {
    _notifiedMilestones.clear();
    _stopProgressReminder();
    _lastCurrent = null;
    _lastGoal = null;
    _lastUserName = null;
  }
}
