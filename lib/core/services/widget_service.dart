import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String _androidWidgetLarge = 'HomeWidgetLargeProvider';
  static const String _androidWidgetSmall = 'HomeWidgetSmallProvider';

  /// Mesmo incremento do FAB central na home (ml).
  static const int widgetQuickAddMl = 50;

  /// Atualiza dados exibidos nos widgets Android (layouts nativos RemoteViews).
  static Future<void> updateHomeWidget({
    required double progress,
    required int currentIntake,
    required int goal,
  }) async {
    try {
      await HomeWidget.setAppGroupId('group.com.example.bebeu');

      await HomeWidget.saveWidgetData<int>('currentIntake', currentIntake);
      await HomeWidget.saveWidgetData<int>('goal', goal);
      await HomeWidget.saveWidgetData<int>(
        'progressPercent',
        (progress * 100).toInt(),
      );

      await HomeWidget.updateWidget(name: _androidWidgetLarge);
      await HomeWidget.updateWidget(name: _androidWidgetSmall);
    } catch (e, stackTrace) {
      // Evita quebrar fluxo do app; log em debug se necessário.
      assert(() {
        // ignore: avoid_print
        print('Erro ao atualizar home widget: $e\n$stackTrace');
        return true;
      }());
    }
  }
}
