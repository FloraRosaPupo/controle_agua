import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'api/api_client.dart';
import 'services/widget_service.dart';
import '../data/services/water_service.dart';
import '../data/services/settings_service.dart';
import 'services/notification_service.dart';

const _storage = FlutterSecureStorage(
  aOptions: AndroidOptions(encryptedSharedPreferences: true),
  iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
);

/// Chamado pelo Android ao tocar em "+" no widget (broadcast em segundo plano).
@pragma('vm:entry-point')
Future<void> homeWidgetInteractiveCallback(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  final host = uri?.host.toLowerCase();
  final path = uri?.path.toLowerCase();
  debugPrint('[Widget +] Callback recebido | uri=$uri | host=$host | path=$path');
  if (host != 'addwater' && path != '/addwater') return;

  try {
    await HomeWidget.setAppGroupId('group.com.example.bebeu');
    debugPrint('[Widget +] AppGroup configurado');

    final token = await _storage.read(key: 'jwt_token');
    if (token == null || token.isEmpty) {
      debugPrint('[Widget +] Token ausente no secure storage');
      return;
    }
    debugPrint('[Widget +] Token encontrado (len=${token.length})');

    final client = ApiClient();
    client.setToken(token);
    final water = WaterService(client);
    final settingsService = SettingsService(client);
    final notify = NotificationService();
    await notify.initialize(requestPermissions: false);
    debugPrint('[Widget +] NotificationService inicializado');

    var quickAddAmount = 200;
    var fallbackGoal = 2000;
    try {
      final settingsInfo = await settingsService.getSettings();
      quickAddAmount = (settingsInfo['quickAddAmount'] as num?)?.toInt() ?? 200;
      fallbackGoal = (settingsInfo['dailyGoal'] as num?)?.toInt() ?? 2000;
      debugPrint(
        '[Widget +] Settings carregadas | quickAdd=$quickAddAmount | dailyGoal=$fallbackGoal',
      );
    } catch (_) {
      // Se falhar carregar ajustes, continua com fallback local.
      debugPrint(
        '[Widget +] Falha ao carregar settings, usando fallback | quickAdd=$quickAddAmount | dailyGoal=$fallbackGoal',
      );
    }

    debugPrint('[Widget +] Enviando addWater(amount=$quickAddAmount)');
    final added = await water.addWater(quickAddAmount);
    if (!added) {
      throw Exception('addWater retornou false');
    }
    debugPrint('[Widget +] addWater concluido com sucesso');

    try {
      final data = await water.getTodayData();
      final total = data?.total ?? 0;
      final goal = (data?.dailyGoal ?? fallbackGoal).clamp(1, 100000);
      final progress = (total / goal).clamp(0.0, 1.0);
      final percent = (progress * 100).toInt().clamp(0, 100);
      final status = 'Você adicionou ${quickAddAmount}ml';
      await notify.showProgressNotification(
        id: 995,
        title: '+${quickAddAmount}ml registrado ✅',
        currentMl: total,
        goalMl: goal,
        percent: percent,
        statusText: status,
        ongoing: false,
      );
      debugPrint('[Widget +] Notificacao de progresso exibida');
      debugPrint(
        '[Widget +] getTodayData ok | total=$total | goal=$goal | progress=${(progress * 100).toStringAsFixed(1)}%',
      );
      await WidgetService.updateHomeWidget(
        progress: progress,
        currentIntake: total,
        goal: goal,
      );
      debugPrint('[Widget +] Widget atualizado');
    } catch (e) {
      await notify.showNotification(
        id: 8888,
        title: 'Bebeu?',
        body: '+ $quickAddAmount ml adicionados',
      );
      debugPrint(
        'Widget: água adicionada, mas falhou ao montar progresso/sincronizar UI: $e',
      );
    }
  } catch (e, st) {
    try {
      await NotificationService().showNotification(
        id: 8889,
        title: 'Bebeu?',
        body: 'Sinal fraco, tente novamente.',
      );
    } catch (_) {}
    debugPrint('[Widget +] ERRO no callback: $e');
    debugPrint('[Widget +] STACKTRACE: $st');
  }
}
