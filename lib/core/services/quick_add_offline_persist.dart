import '../../features/hydration/data/local/user_goal_cache.dart';
import 'local_database_service.dart';
import 'notification_service.dart';
import 'widget_service.dart';

/// Enfileira ml no SQLite e atualiza o widget (só para falha de rede / sem ligação).
Future<void> persistQuickAddWaterOffline({
  required int amountMl,
  required int fallbackGoalMl,
  required NotificationService notify,
}) async {
  await LocalDatabaseService.addPendingLog(amountMl);

  final cached = await LocalDatabaseService.getCachedData();
  final cachedIntake = cached?['total_intake'] as int? ?? 0;
  final goal = (cached?['daily_goal'] as int? ?? fallbackGoalMl).clamp(
    1,
    100000,
  );
  final newIntake = cachedIntake + amountMl;

  await LocalDatabaseService.updateCachedIntake(newIntake);

  final progress = (newIntake / goal).clamp(0.0, 1.0);
  await WidgetService.updateHomeWidget(
    progress: progress,
    currentIntake: newIntake,
    goal: goal,
  );
  await UserGoalCache.setDailyGoalMl(goal);

  await notify.showNotification(
    id: 8888,
    title: 'Bebeu? 💧',
    body: '+${amountMl}ml guardado. Será sincronizado quando conectar.',
  );
}
