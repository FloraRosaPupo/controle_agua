import 'package:bebeu/core/services/widget_service.dart';

class HomeController {
  final String userName = "Alex Silva";
  int _currentIntake = 1200;
  int get currentIntake => _currentIntake;
  final int dailyGoal = 2000;

  HomeController() {
    updateWidget();
  }

  void addWater(int ml) {
    _currentIntake += ml;
    updateWidget();
  }

  List<Map<String, dynamic>> todayHistory = [
    {"type": "Água Mineral", "time": "10:15 AM", "amount": 300},
    {"type": "Água Mineral", "time": "08:30 AM", "amount": 250},
    {"type": "Água Mineral", "time": "07:15 AM", "amount": 650},
  ];

  double get progress => currentIntake / dailyGoal;
  int get percentage => (progress * 100).toInt();

  void updateWidget() {
    WidgetService.updateHomeWidget(
      progress: progress,
      currentIntake: currentIntake,
      goal: dailyGoal,
    );
  }

  void dispose() {
    // Para uso futuro se tivermos TextEditingControllers ou Observables
  }
}
