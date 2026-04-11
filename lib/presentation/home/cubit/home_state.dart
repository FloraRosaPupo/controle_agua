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
  final int syncedCount; // > 0 quando acabou de sincronizar

  HomeLoaded({
    required this.currentIntake,
    required this.dailyGoal,
    required this.userName,
    required this.progress,
    required this.percentage,
    required this.todayHistory,
    this.syncedCount = 0,
  });
}

class HomeOffline extends HomeState {
  final int currentIntake;
  final int dailyGoal;
  final String userName;
  final double progress;
  final int percentage;
  final int pendingCount;
  final int pendingAmount;
  final bool isSyncing;

  HomeOffline({
    required this.currentIntake,
    required this.dailyGoal,
    required this.userName,
    required this.progress,
    required this.percentage,
    required this.pendingCount,
    required this.pendingAmount,
    this.isSyncing = false,
  });
}

class HomeError extends HomeState {
  final String message;
  HomeError(this.message);
}
