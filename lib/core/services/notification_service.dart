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
  static const String _scheduledReminderPayload = 'hydration_recurring';
  static const String _quickAddActionId = 'quick_add_water';
  static const int _fallbackQuickAddAmountMl = 200;
  static const int _scheduledReminderIdBase = 20000;
  static const int _progressNotificationId = 50001;
  static const int _goalReachedNotificationId = 50002;

  Future<int> Function()? _quickAddAmountResolver;
  Future<void> Function(int ml)? _onQuickAddFromNotification;

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

  Future<void> initialize({bool requestPermissions = true}) async {
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
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    // Request notification permission on Android 13+
    final androidPlugin = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin != null) {
      if (requestPermissions) {
        await androidPlugin.requestNotificationsPermission();
        // Alarmes agendados: inexact costuma não disparar no horário com Doze / Android 14+.
        await androidPlugin.requestExactAlarmsPermission();
      }
      await _syncAndroidChannels();
    }
  }

  /// Conecta o botão "+" das notificações com a lógica real de adicionar água.
  void configureQuickAddAction({
    Future<int> Function()? resolveQuickAddAmount,
    Future<void> Function(int ml)? onQuickAdd,
  }) {
    _quickAddAmountResolver = resolveQuickAddAmount;
    _onQuickAddFromNotification = onQuickAdd;
  }

  Future<void> _onNotificationResponse(NotificationResponse details) async {
    final isQuickAddAction = details.actionId == _quickAddActionId;
    final isRecurringReminder = details.payload == _scheduledReminderPayload;
    if (!isQuickAddAction || !isRecurringReminder) return;

    final quickAddMl = await _resolveQuickAddAmount();
    final handler = _onQuickAddFromNotification;
    if (handler == null) {
      debugPrint(
        '[BebeuNotify] Ação "+" ignorada: handler de quick add não configurado.',
      );
      return;
    }

    try {
      await handler(quickAddMl);
      debugPrint('[BebeuNotify] Ação "+" executada (+${quickAddMl}ml).');
    } catch (e) {
      debugPrint('[BebeuNotify] Falha ao executar ação "+" da notificação: $e');
    }
  }

  Future<int> _resolveQuickAddAmount() async {
    final resolver = _quickAddAmountResolver;
    if (resolver == null) return _fallbackQuickAddAmountMl;
    try {
      final value = await resolver();
      return value > 0 ? value : _fallbackQuickAddAmountMl;
    } catch (_) {
      return _fallbackQuickAddAmountMl;
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

  /// Dispara imediatamente um lembrete com a mesma ação "+" dos recorrentes.
  Future<void> showRecurringReminderTestNotification() async {
    if (kIsWeb) return;

    final quickAddMlForAction = await _resolveQuickAddAmount();
    final quickAddLabel = '+ ${quickAddMlForAction}ml';
    final message = _nextReminderMessage();

    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 2147483647,
      title: 'Bebeu?',
      body: message,
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
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction(
              _quickAddActionId,
              quickAddLabel,
              showsUserInterface: true,
              cancelNotification: true,
            ),
          ],
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: _scheduledReminderPayload,
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
    if (kDebugMode) return raw;
    return raw < 30 ? 30 : raw;
  }

  int _normalizedEndMinutes({
    required int startTotalMinutes,
    required int endTotalMinutes,
  }) {
    // UX comum: usuário define "00:00" como fim do dia.
    if (endTotalMinutes == 0 && startTotalMinutes > 0) {
      return 23 * 60 + 59;
    }
    return endTotalMinutes;
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
    final endTotalMinutes = _normalizedEndMinutes(
      startTotalMinutes: startTotalMinutes,
      endTotalMinutes: endTime.hour * 60 + endTime.minute,
    );

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
    'Bebeu água? Ta com sede?',
    'Hora de beber água! Mantenha seu corpo hidratado.',
    'Beba um copo d\'água agora! Se cuida.',
    'Não esqueça da sua meta! Um pequeno gole faz diferença.',
    'Hidratação é saúde! Que tal um pouco d\'água agora?',
    'Água é vida! Vamos bater a meta de hoje?',
    'Seu corpo agradece: hora de beber água.',
    'Um lembrete amigo: tome água e siga firme.',
    'Pausa rápida para hidratar? Seu bem-estar agradece.',
    'Mais um gole e você fica mais perto da meta.',
    'Respira fundo e bebe água: você merece esse cuidado.',
    'Manter a hidratação em dia faz toda diferença.',
    'Que tal um copo de água agora para renovar as energias?',
    'Hidratar-se também é produtividade. Bora tomar água!',
    'Bebeu água hoje? Este é seu lembrete carinhoso.',
    'Pequenos goles ao longo do dia, grandes resultados.',
    'Seu próximo copo d\'água está te esperando.',
    'Hora de cuidar de você com um pouco de água.',
    'Água na rotina: simples, leve e essencial.',
    'Siga no ritmo da hidratação e bata sua meta.',
    'Não deixe para depois: um gole agora já ajuda.',
    'Água gelada ou natural? O importante é beber agora!',
    'Seu corpo pede: mais um gole de água para o dia brilhar.',
    'Lembrete do dia: hidrate-se e sinta a energia voltar.',
    'Meta de água quase lá! Vamos com mais um copinho?',
    'Cuidado com você: hora de recarregar com água fresca.',
    'Beba água e transforme o dia em algo incrível.',
    'Pequena vitória: um gole de água a cada lembrete.',
    'Hidratação full: seu superpoder para o dia todo.',
    'Não para! Água agora e meta batida no final do dia.',
    'Você consegue: mais água para um corpo forte e feliz.',
  ];
  String _nextReminderMessage() {
    return _reminderMessages[math.Random().nextInt(_reminderMessages.length)];
  }

  Future<void> _scheduleHydrationRemindersImpl(
    NotificationPreferences prefs,
  ) async {
    await _cancelScheduledRemindersOnly();
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
    final endTotalMinutes = _normalizedEndMinutes(
      startTotalMinutes: startTotalMinutes,
      endTotalMinutes: endTime.hour * 60 + endTime.minute,
    );
    final quickAddMlForAction = await _resolveQuickAddAmount();
    final quickAddLabel = '+ ${quickAddMlForAction}ml';

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
      for (final total in marks) {
        final hour = total ~/ 60;
        final minute = total % 60;
        final message = _nextReminderMessage();
        scheduledCount++;
        await _notificationsPlugin.zonedSchedule(
          id: _scheduledReminderIdBase + total,
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
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  _quickAddActionId,
                  quickAddLabel,
                  // Abre a UI para garantir que o callback rode e some água.
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: _scheduledReminderPayload,
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
      for (final s in slots) {
        final hour = s.totalMinutes ~/ 60;
        final minute = s.totalMinutes % 60;
        final message = _nextReminderMessage();
        scheduledCount++;
        await _notificationsPlugin.zonedSchedule(
          id: _scheduledReminderIdBase + (s.weekday * 1440 + s.totalMinutes),
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
              actions: <AndroidNotificationAction>[
                AndroidNotificationAction(
                  _quickAddActionId,
                  quickAddLabel,
                  // Abre a UI para garantir que o callback rode e some água.
                  showsUserInterface: true,
                  cancelNotification: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: _scheduledReminderPayload,
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
      _notificationsPlugin.cancel(id: _progressNotificationId);
      showProgressNotification(
        id: _goalReachedNotificationId,
        title: '🎉 Meta atingida, $userName!',
        currentMl: current,
        goalMl: goal,
        percent: percent.clamp(0, 100),
        statusText: 'Parabéns! Você completou sua meta de ${goal}ml',
        ongoing: false,
      );
    } else if (percent >= 80 &&
        percent < 100 &&
        !_notifiedMilestones.contains(80)) {
      _notifiedMilestones.add(80);
      _startProgressReminder();
      final reminderMessage = _nextReminderMessage();
      showProgressNotification(
        id: _progressNotificationId,
        title: '💧 Quase lá, $userName!',
        currentMl: current,
        goalMl: goal,
        percent: percent,
        statusText: reminderMessage,
        ongoing: false,
      );
    } else if (percent >= 70 &&
        percent < 80 &&
        !_notifiedMilestones.contains(70)) {
      _notifiedMilestones.add(70);
      _startProgressReminder();
      final reminderMessage = _nextReminderMessage();
      showProgressNotification(
        id: _progressNotificationId,
        title: '👏 Bom progresso, $userName!',
        currentMl: current,
        goalMl: goal,
        percent: percent,
        statusText: reminderMessage,
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
    if (_lastCurrent! >= _lastGoal!) return;
    if (_notifiedMilestones.contains(100)) return;

    final percent = ((_lastCurrent! / _lastGoal!) * 100).toInt();
    if (percent >= 100) return;
    if (percent < 70) return;

    final String title;
    final String statusText;
    final reminderMessage = _nextReminderMessage();

    if (percent >= 80) {
      title = '💧 Quase lá, $_lastUserName!';
      statusText = reminderMessage;
    } else {
      title = '👏 Bom progresso, $_lastUserName!';
      statusText = reminderMessage;
    }

    showProgressNotification(
      id: _progressNotificationId,
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

  Future<void> _cancelScheduledRemindersOnly() async {
    final pending = await _notificationsPlugin.pendingNotificationRequests();
    for (final request in pending) {
      if (request.payload == _scheduledReminderPayload ||
          (request.id >= _scheduledReminderIdBase && request.id <= 40000)) {
        await _notificationsPlugin.cancel(id: request.id);
      }
    }
  }
}
