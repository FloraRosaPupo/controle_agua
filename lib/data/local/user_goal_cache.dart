import 'package:shared_preferences/shared_preferences.dart';

/// Meta diária (ml) guardada localmente para leituras sem rede (ex.: "+" na notificação).
class UserGoalCache {
  UserGoalCache._();

  static const _keyDailyGoalMl = 'user_daily_goal_ml';
  static const _keyQuickAddMl = 'user_quick_add_ml';

  static Future<void> setDailyGoalMl(int goalMl) async {
    if (goalMl <= 0) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyDailyGoalMl, goalMl.clamp(1, 100000));
  }

  static Future<int> getDailyGoalMlOrDefault([int defaultMl = 2000]) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyDailyGoalMl) ?? defaultMl;
  }

  static Future<void> setQuickAddMl(int ml) async {
    if (ml <= 0) return;
    final p = await SharedPreferences.getInstance();
    await p.setInt(_keyQuickAddMl, ml.clamp(10, 2000));
  }

  static Future<int> getQuickAddMlOrDefault([int defaultMl = 200]) async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_keyQuickAddMl) ?? defaultMl;
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_keyDailyGoalMl);
    await p.remove(_keyQuickAddMl);
  }
}
