import 'dart:ui';

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'widget_service.dart';

/// ID estável no `AlarmManager` (não colidir com outros alarmes do app).
const int kMidnightWidgetAlarmId = 88997701;

@pragma('vm:entry-point')
void midnightWidgetAlarmCallback(int id) {
  // O dispatcher do plugin não aguarda Futures; disparamos o trabalho async aqui.
  _midnightWidgetAlarmImpl(id);
}

Future<void> _midnightWidgetAlarmImpl(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    //seta o app group id para o widget
    await HomeWidget.setAppGroupId('group.com.example.bebeu');
    //pega a meta do usuário
    final goal = (await HomeWidget.getWidgetData<int>(
          'goal',
          defaultValue: 2000,
        ) ??
        2000)
        .clamp(1, 100000);
    await WidgetService.updateHomeWidget(
      progress: 0, //progress do usuário
      currentIntake: 0, //ingestão do usuário
      goal: goal, //meta do usuário
    );
  } catch (e, st) {
    assert(() {
      // ignore: avoid_print
      print('[MidnightWidgetAlarm] $e\n$st');
      return true;
    }());
  }
  await MidnightWidgetAlarm.schedule();
}

/// Agenda um alarme à próxima meia-noite (hora local) para zerar o intake no widget.
class MidnightWidgetAlarm {
  MidnightWidgetAlarm._();

  /// Verifica se o alarme está inicializado
  static Future<bool> ensureInitialized() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    return AndroidAlarmManager.initialize();
  }

  /// Próxima 00:00 local; mantém a meta já gravada no `HomeWidget` e zera ingestão.
  static Future<void> schedule() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    //pega a data e hora atual
    final now = DateTime.now();
    //pega a próxima meia-noite
    var nextMidnight = DateTime(now.year, now.month, now.day + 1);
    if (!nextMidnight.isAfter(now)) {
      nextMidnight = nextMidnight.add(const Duration(days: 1));
    }

    await AndroidAlarmManager.cancel(kMidnightWidgetAlarmId);
    await AndroidAlarmManager.oneShotAt(
      nextMidnight,
      kMidnightWidgetAlarmId,
      midnightWidgetAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> cancel() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await AndroidAlarmManager.cancel(kMidnightWidgetAlarmId);
  }
}
