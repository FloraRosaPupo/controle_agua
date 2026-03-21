abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final int currentIntake;
  final int dailyGoal;
  final String userName;
  final double progress;
  final int percentage;
  final List<Map<String, dynamic>> todayHistory;

  HomeLoaded({
    required this.currentIntake,
    required this.dailyGoal,
    required this.userName,
    required this.progress,
    required this.percentage,
    required this.todayHistory,
  });
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}
