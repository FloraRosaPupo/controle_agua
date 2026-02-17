class HomeController {
  final String userName = "Alex Silva";
  final int currentIntake = 1200;
  final int dailyGoal = 2000;

  List<Map<String, dynamic>> todayHistory = [
    {"type": "Água Mineral", "time": "10:15 AM", "amount": 300},
    {"type": "Água Mineral", "time": "08:30 AM", "amount": 250},
    {"type": "Água Mineral", "time": "07:15 AM", "amount": 650},
  ];

  double get progress => currentIntake / dailyGoal;
  int get percentage => (progress * 100).toInt();

  void dispose() {
    // Para uso futuro se tivermos TextEditingControllers ou Observables
  }
}
