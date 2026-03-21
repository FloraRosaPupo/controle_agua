import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/water_service.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/services/notification_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final WaterService _waterService;
  final NotificationService _notificationService = NotificationService();

  HomeCubit(this._waterService) : super(HomeInitial());

  Future<void> loadTodayData() async {
    emit(HomeLoading());

    try {
      final data = await _waterService.getTodayData();
      if (data != null) {
        final currentIntake = data.total;
        final dailyGoal = data.dailyGoal;

        var todayHistory = data.logs
            .map(
              (log) => {
                "type": "Água",
                "amount": log.amount,
                "time": log.date.toLocal().toString().substring(11, 16),
              },
            )
            .toList();

        todayHistory = todayHistory.reversed.toList();

        final progress = dailyGoal == 0
            ? 0.0
            : (currentIntake / dailyGoal).clamp(0.0, 1.0);
        final percentage = (progress * 100).toInt();

        _updateWidget(progress, currentIntake, dailyGoal);

        emit(
          HomeLoaded(
            currentIntake: currentIntake,
            dailyGoal: dailyGoal,
            userName: data.name,
            progress: progress,
            percentage: percentage,
            todayHistory: todayHistory,
          ),
        );

        _notificationService.checkProgressAndNotify(
          current: currentIntake,
          goal: dailyGoal,
          userName: data.name,
        );
      } else {
        emit(HomeError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      emit(HomeError('Erro ao carregar dados: $e'));
    }
  }

  Future<void> addWater(int ml) async {
    // Ação baseada somente se os dados originais já existirem na tela
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;

      final optimisticIntake = currentState.currentIntake + ml;
      final optimisticHistory = List<Map<String, dynamic>>.from(
        currentState.todayHistory,
      );
      optimisticHistory.insert(0, {
        "type": "Água",
        "amount": ml,
        "time": "Agora",
      });

      final progress = currentState.dailyGoal == 0
          ? 0.0
          : (optimisticIntake / currentState.dailyGoal).clamp(0.0, 1.0);

      _updateWidget(progress, optimisticIntake, currentState.dailyGoal);

      // Emitimos uma visão otimista (UI rápida!)
      emit(
        HomeLoaded(
          currentIntake: optimisticIntake,
          dailyGoal: currentState.dailyGoal,
          userName: currentState.userName,
          progress: progress,
          percentage: (progress * 100).toInt(),
          todayHistory: optimisticHistory,
        ),
      );

      _notificationService.checkProgressAndNotify(
        current: optimisticIntake,
        goal: currentState.dailyGoal,
        userName: currentState.userName,
      );

      try {
        await _waterService.addWater(ml);
      } catch (e) {
        // Se a API falhar, reverter de volta pra visão anterior
        _updateWidget(
          currentState.progress,
          currentState.currentIntake,
          currentState.dailyGoal,
        );
        emit(currentState);
        // Opcional: Emitir um erro rapidinho ou Snackbar, precisaria ser tratado na View.
      }
    }
  }

  void _updateWidget(double progress, int currentIntake, int goal) {
    WidgetService.updateHomeWidget(
      progress: progress,
      currentIntake: currentIntake,
      goal: goal,
    );
  }
}
