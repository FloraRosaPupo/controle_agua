import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api/api_client.dart';
import 'services/widget_service.dart';
import '../data/services/water_service.dart';

/// Chamado pelo Android ao tocar em "+" no widget (broadcast em segundo plano).
@pragma('vm:entry-point')
Future<void> homeWidgetInteractiveCallback(Uri? uri) async {
  if (uri?.host != 'addwater') return;

  WidgetsFlutterBinding.ensureInitialized();
  await HomeWidget.setAppGroupId('group.com.example.bebeu');

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('jwt_token');
  if (token == null || token.isEmpty) return;

  final client = ApiClient();
  client.setToken(token);
  final water = WaterService(client);

  try {
    await water.addWater(WidgetService.widgetQuickAddMl);
    final data = await water.getTodayData();
    if (data != null) {
      final progress = data.dailyGoal == 0
          ? 0.0
          : (data.total / data.dailyGoal).clamp(0.0, 1.0);
      await WidgetService.updateHomeWidget(
        progress: progress,
        currentIntake: data.total,
        goal: data.dailyGoal,
      );
    }
  } catch (_) {
    // Falha silenciosa no widget; usuário pode abrir o app.
  }
}
