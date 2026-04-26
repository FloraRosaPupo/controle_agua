import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/app_jwt.dart';
import 'config/supabase_env.dart';
import 'config/load_supabase_env_assets.dart';
import 'config/load_supabase_local_stub.dart'
    if (dart.library.io) 'config/load_supabase_local_io.dart' as supa_local;
import 'services/widget_service.dart';
import '../data/services/water_service.dart';
import '../data/services/settings_service.dart';
import '../data/services/local_database_service.dart';
import '../data/services/connectivity_service.dart';
import 'services/notification_service.dart';

/// Chamado pelo Android ao tocar em "+" no widget (broadcast em segundo plano).
@pragma('vm:entry-point')
Future<void> homeWidgetInteractiveCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await loadSupabaseEnvFromAssets();
  supa_local.tryLoadSupabaseLocalJson();
  await AppJwt.hydrate();

  final host = uri?.host.toLowerCase();
  final path = uri?.path.toLowerCase();
  debugPrint(
    '[Widget +] Callback recebido | uri=$uri | host=$host | path=$path',
  );
  if (host != 'addwater' && path != '/addwater') return;

  final notify = NotificationService();
  await notify.initialize(requestPermissions: false);

  try {
    await HomeWidget.setAppGroupId('group.com.example.bebeu');

    if (!SupabaseEnv.hasAnonKey) {
      debugPrint('[Widget +] SUPABASE_ANON_KEY ausente em app.env');
      return;
    }

    if (!Supabase.instance.isInitialized) {
      await Supabase.initialize(
        url: SupabaseEnv.urlResolved,
        anonKey: SupabaseEnv.anonKey,
      );
    }

    final jwt = await AppJwt.bearerForSupabase();
    if (jwt == null || jwt.isEmpty) {
      debugPrint('[Widget +] Sem JWT — faça login no app.');
      return;
    }

    var quickAddAmount = 200;
    var fallbackGoal = 2000;

    final isConnected = await ConnectivityService.isConnected();
    debugPrint('[Widget +] Conectado=$isConnected');

    if (!isConnected) {
      await _saveOffline(quickAddAmount, fallbackGoal, notify);
      return;
    }

    final water = WaterService();
    final settingsService = SettingsService();

    try {
      final settingsInfo = await settingsService.getSettings();
      quickAddAmount = (settingsInfo['quickAddAmount'] as num?)?.toInt() ?? 200;
      fallbackGoal = (settingsInfo['dailyGoal'] as num?)?.toInt() ?? 2000;
      debugPrint(
        '[Widget +] Settings | quickAdd=$quickAddAmount | goal=$fallbackGoal',
      );
    } catch (_) {
      debugPrint(
        '[Widget +] Fallback settings | quickAdd=$quickAddAmount | goal=$fallbackGoal',
      );
    }

    bool added = false;
    try {
      debugPrint('[Widget +] Enviando addWater($quickAddAmount)');
      added = await water.addWater(quickAddAmount);
    } catch (e) {
      debugPrint('[Widget +] addWater falhou: $e — salvando offline');
      await _saveOffline(quickAddAmount, fallbackGoal, notify);
      return;
    }

    if (!added) {
      debugPrint('[Widget +] addWater retornou false — salvando offline');
      await _saveOffline(quickAddAmount, fallbackGoal, notify);
      return;
    }

    debugPrint('[Widget +] addWater OK');

    try {
      final data = await water.getTodayData();
      final total = data?.total ?? 0;
      final goal = (data?.dailyGoal ?? fallbackGoal).clamp(1, 100000);
      final progress = (total / goal).clamp(0.0, 1.0);
      final percent = (progress * 100).toInt().clamp(0, 100);

      await notify.showProgressNotification(
        id: 995,
        title: '+${quickAddAmount}ml registrado ✅',
        currentMl: total,
        goalMl: goal,
        percent: percent,
        statusText: 'Você adicionou ${quickAddAmount}ml',
        ongoing: false,
      );
      await WidgetService.updateHomeWidget(
        progress: progress,
        currentIntake: total,
        goal: goal,
      );
      debugPrint('[Widget +] Widget atualizado | total=$total goal=$goal');
    } catch (e) {
      await notify.showNotification(
        id: 8888,
        title: 'Bebeu? 💧',
        body: '+${quickAddAmount}ml adicionados',
      );
      debugPrint('[Widget +] Falha ao sincronizar UI pós-add: $e');
    }
  } catch (e, st) {
    try {
      await notify.showNotification(
        id: 8889,
        title: 'Bebeu? 💧',
        body: 'Não foi possível registrar. Tente pelo app.',
      );
    } catch (_) {}
    debugPrint('[Widget +] ERRO: $e');
    debugPrint('[Widget +] STACKTRACE: $st');
  }
}

Future<void> _saveOffline(
  int amount,
  int fallbackGoal,
  NotificationService notify,
) async {
  try {
    await LocalDatabaseService.addPendingLog(amount);

    final cached = await LocalDatabaseService.getCachedData();
    final cachedIntake = cached?['total_intake'] as int? ?? 0;
    final goal = (cached?['daily_goal'] as int? ?? fallbackGoal).clamp(
      1,
      100000,
    );
    final newIntake = cachedIntake + amount;

    await LocalDatabaseService.updateCachedIntake(newIntake);

    final progress = (newIntake / goal).clamp(0.0, 1.0);
    await WidgetService.updateHomeWidget(
      progress: progress,
      currentIntake: newIntake,
      goal: goal,
    );

    await notify.showNotification(
      id: 8888,
      title: 'Bebeu? 💧',
      body: '+${amount}ml guardado. Será sincronizado quando conectar.',
    );
    debugPrint('[Widget +] Offline: $amount ml salvo localmente');
  } catch (e) {
    debugPrint('[Widget +] Erro ao salvar offline: $e');
  }
}
