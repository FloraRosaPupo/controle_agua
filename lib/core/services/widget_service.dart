import 'package:home_widget/home_widget.dart';
import 'package:flutter/material.dart';
import 'package:bebeu/presentation/home/widgets/home_screen_widgets.dart';

class WidgetService {
  static const String _androidWidgetLarge = 'HomeWidgetLargeProvider';
  static const String _androidWidgetSmall = 'HomeWidgetSmallProvider';

  static Future<void> updateHomeWidget({
    required double progress,
    required int currentIntake,
    required int goal,
  }) async {
    try {
      print('🚀 Iniciando atualização dos widgets...');

      await HomeWidget.setAppGroupId('group.com.example.bebeu');

      // Salva dados para o layout padrão (mostra ao instalar, antes do app rodar)
      await HomeWidget.saveWidgetData<int>('currentIntake', currentIntake);
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.saveWidgetData<int>('progressPercent', (progress * 100).toInt());

      // 1. Render widget grande (transparente)
      final pathLarge = await HomeWidget.renderFlutterWidget(
        Material(
          color: Colors.transparent,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: HomeWidgetLarge(
              progress: progress,
              currentIntake: currentIntake,
              goal: goal,
            ),
          ),
        ),
        key: 'filename',
        logicalSize: const Size(400, 200),
      );

      if (pathLarge != null) {
        await HomeWidget.updateWidget(name: _androidWidgetLarge);
        print('✅ Widget grande atualizado: $pathLarge');
      }

      // 2. Render widget pequeno (transparente)
      final pathSmall = await HomeWidget.renderFlutterWidget(
        Material(
          color: Colors.transparent,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: HomeWidgetSmall(progress: progress),
          ),
        ),
        key: 'filename_small',
        logicalSize: const Size(200, 200),
      );

      if (pathSmall != null) {
        await HomeWidget.updateWidget(name: _androidWidgetSmall);
        print('✅ Widget pequeno atualizado: $pathSmall');
      }
    } catch (e, stackTrace) {
      print('❌ Erro crítico ao atualizar widget: $e');
      print(stackTrace);
    }
  }
}
