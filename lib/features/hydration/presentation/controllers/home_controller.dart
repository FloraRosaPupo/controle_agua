import 'package:flutter/material.dart';
import 'package:bebeu/features/hydration/data/water_service.dart';
import 'package:bebeu/core/services/widget_service.dart';

class HomeController extends ChangeNotifier {
  final WaterService _waterService = WaterService();

  String userName = "Alex Silva";
  int _currentIntake = 0;
  int _dailyGoal = 2000;
  bool isLoading = false;

  int get currentIntake => _currentIntake;
  int get dailyGoal => _dailyGoal;

  double get progress =>
      dailyGoal == 0 ? 0 : (_currentIntake / dailyGoal).clamp(0.0, 1.0);
  int get percentage => (progress * 100).toInt();

  List<Map<String, dynamic>> todayHistory = [];

  HomeController() {
    loadTodayData();
  }

  Future<void> loadTodayData() async {
    isLoading = true;
    notifyListeners();

    try {
      final data = await _waterService.getTodayData();
      if (data != null) {
        _currentIntake = data.total;
        _dailyGoal = data.dailyGoal;

        todayHistory = data.logs
            .map(
              (log) => {
                "type": "Água",
                "amount": log.amount,
                "time": log.date.toLocal().toString().substring(11, 16),
              },
            )
            .toList();

        // Colocando os mais recentes no topo
        todayHistory = todayHistory.reversed.toList();
      }
    } catch (e) {
      debugPrint('Erro ao carregar dados: $e');
    } finally {
      isLoading = false;
      updateWidget();
      notifyListeners();
    }
  }

  Future<void> addWater(int ml) async {
    // Atualização otimista
    _currentIntake += ml;
    todayHistory.insert(0, {"type": "Água", "amount": ml, "time": "Agora"});
    notifyListeners();

    try {
      await _waterService.addWater(ml);
    } catch (e) {
      debugPrint('Erro ao salvar água: $e');
      // Reverter se falhar
      _currentIntake -= ml;
      todayHistory.removeAt(0);
    } finally {
      updateWidget();
      notifyListeners();
    }
  }

  void updateWidget() {
    WidgetService.updateHomeWidget(
      progress: progress,
      currentIntake: currentIntake,
      goal: dailyGoal,
    );
  }

  @override
  void dispose() {
    super.dispose();
  }
}
