abstract class HistoryState {}

class HistoryInitial extends HistoryState {}

class HistoryLoading extends HistoryState {}

class HistoryLoaded extends HistoryState {
  final List<dynamic> logs;
  final int dailyGoal;
  final Map<String, dynamic> stats;
  final String selectedPeriod;

  HistoryLoaded({
    required this.logs,
    required this.dailyGoal,
    required this.stats,
    required this.selectedPeriod,
  });
}

class HistoryError extends HistoryState {
  final String message;
  HistoryError(this.message);
}
