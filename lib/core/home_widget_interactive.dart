import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'auth/app_jwt.dart';
import 'config/supabase_env.dart';
import 'config/load_supabase_env_assets.dart';
import 'config/load_supabase_local_stub.dart'
    if (dart.library.io) 'config/load_supabase_local_io.dart' as supa_local;
import 'services/quick_add_offline_persist.dart';
import 'services/widget_service.dart';
import '../data/local/user_goal_cache.dart';
import '../data/services/water_service.dart';
import '../data/services/settings_service.dart';
import 'services/notification_service.dart';
import 'utils/network_error_heuristics.dart';

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

    var quickAddAmount = await UserGoalCache.getQuickAddMlOrDefault();
    var fallbackGoal = await UserGoalCache.getDailyGoalMlOrDefault();

    debugPrint(
      '[Widget +] Pré-add | quickAdd=$quickAddAmount | meta=$fallbackGoal '
      '(tentamos API primeiro — connectivity pode indicar offline com Wi‑Fi)',
    );

    final water = WaterService();
    final settingsService = SettingsService();

    try {
      final settingsInfo = await settingsService.getSettings();
      quickAddAmount = (settingsInfo['quickAddAmount'] as num?)?.toInt() ??
          quickAddAmount;
      final g = (settingsInfo['dailyGoal'] as num?)?.toInt();
      if (g != null && g > 0) {
        fallbackGoal = g;
        await UserGoalCache.setDailyGoalMl(g);
      }
      await UserGoalCache.setQuickAddMl(quickAddAmount);
      debugPrint(
        '[Widget +] Settings | quickAdd=$quickAddAmount | goal=$fallbackGoal',
      );
    } catch (_) {
      debugPrint(
        '[Widget +] Fallback settings | quickAdd=$quickAddAmount | goal=$fallbackGoal',
      );
    }

    try {
      debugPrint('[Widget +] Enviando addWater($quickAddAmount)');
      await water.addWater(quickAddAmount);
    } catch (e) {
      // Só fila offline se o erro parecer transporte/rede (evita “sem rede” com Wi‑Fi ligado).
      final treatAsOffline = messageSuggestsNetworkFailure(e.toString());
      if (treatAsOffline) {
        debugPrint('[Widget +] addWater falhou (rede): $e — gravando SQLite');
        await persistQuickAddWaterOffline(
          amountMl: quickAddAmount,
          fallbackGoalMl: fallbackGoal,
          notify: notify,
        );
      } else {
        debugPrint('[Widget +] addWater falhou (API/servidor): $e');
        await notify.showNotification(
          id: 8890,
          title: 'Bebeu? 💧',
          body: 'Não foi possível registrar agora. Abra o app e tente de novo.',
        );
      }
      return;
    }

    debugPrint('[Widget +] addWater OK');

    try {
      final data = await water.getTodayData();
      final total = data?.total ?? 0;
      final goal = (data?.dailyGoal ?? fallbackGoal).clamp(1, 100000);
      final progress = (total / goal).clamp(0.0, 1.0);
      final percent = goal > 0 ? ((total * 100) ~/ goal) : 0;

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
        quickAddMl: quickAddAmount,
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
