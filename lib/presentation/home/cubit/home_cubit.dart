import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/daily_water_data_model.dart';
import '../../../data/models/water_log_model.dart';
import '../../../data/services/water_service.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/services/notification_service.dart';
import 'home_state.dart';

class HomeCubit extends Cubit<HomeState> {
  final WaterService _waterService;
  final NotificationService _notificationService = NotificationService();

  HomeCubit(this._waterService) : super(HomeInitial());

  Future<DailyWaterDataModel> _resolveTodayDataWithFallback(
    DailyWaterDataModel data,
  ) async {
    if (data.logs.isNotEmpty) return data;

    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    final history = await _waterService.getHistory(date: date);
    final historyLogs = (history?['logs'] as List?) ?? const [];
    if (historyLogs.isEmpty) return data;

    final logs = historyLogs
        .whereType<Map>()
        .map((raw) => WaterLogModel.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
    final total = logs.fold<int>(0, (sum, log) => sum + log.amount);

    return DailyWaterDataModel(
      total: total,
      dailyGoal: data.dailyGoal,
      name: data.name,
      remaining: (data.dailyGoal - total).clamp(0, data.dailyGoal),
      percent: data.dailyGoal == 0 ? 0 : total / data.dailyGoal,
      logs: logs,
    );
  }

  void _emitLoadedFromModel(
    DailyWaterDataModel data, {
    bool notifyProgress = false,
  }) {
    final currentIntake = data.total;
    final dailyGoal = data.dailyGoal;

    var todayHistory = data.logs
        .map(
          (log) => {
            "id": log.id,
            "type": "Água",
            "amount": log.amount,
            "time": log.date.toString().substring(11, 16),
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

    if (notifyProgress) {
      _notificationService.checkProgressAndNotify(
        current: currentIntake,
        goal: dailyGoal,
        userName: data.name,
      );
    }
  }

  Future<void> loadTodayData() async {
    emit(HomeLoading());

    try {
      final data = await _waterService.getTodayData();
      if (data != null) {
        final normalized = await _resolveTodayDataWithFallback(data);
        _emitLoadedFromModel(normalized, notifyProgress: false);
      } else {
        emit(HomeError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      emit(HomeError('Erro ao carregar dados: $e'));
    }
  }

  /// Atualiza o dia sem tela de loading (ex.: meta alterada em Ajustes → voltar em Hoje).
  Future<void> refreshTodayData() async {
    try {
      final data = await _waterService.getTodayData();
      if (data != null) {
        final normalized = await _resolveTodayDataWithFallback(data);
        _emitLoadedFromModel(normalized, notifyProgress: false);
      } else if (state is! HomeLoaded) {
        emit(HomeError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      if (state is! HomeLoaded) {
        emit(HomeError('Erro ao carregar dados: $e'));
      }
    }
  }

  Future<String?> addWater(int ml) async {
    // Só aceita valores positivos
    if (ml <= 0) return null;
    
    // Ação baseada somente se os dados originais já existirem na tela
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;

      final optimisticIntake = currentState.currentIntake + ml;
      final optimisticHistory = List<Map<String, dynamic>>.from(
        currentState.todayHistory,
      );
      optimisticHistory.insert(0, {
        "id": "temp_${DateTime.now().millisecondsSinceEpoch}",
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
        // Recarregar para pegar os IDs corretos do banco (sem loading visual)
        await refreshTodayData();
        return null; // Sucesso
      } catch (e) {
        // Se a API falhar, reverter de volta pra visão anterior
        _updateWidget(
          currentState.progress,
          currentState.currentIntake,
          currentState.dailyGoal,
        );
        emit(currentState);
        
        // Retornar a mensagem de falha para a UI tratar
        return "Sinal fraco, tente novamente.";
      }
    }
    return null;
  }

  Future<void> deleteWaterLog(String id) async {
    debugPrint('🗑️ deleteWaterLog chamado com id: $id');
    
    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      debugPrint('📊 Estado atual: intake=${currentState.currentIntake}, history=${currentState.todayHistory.length} items');

      // Visão otimista: remove localmente primeiro
      final logIndex = currentState.todayHistory.indexWhere((log) => log['id'] == id);
      
      if (logIndex == -1) {
        debugPrint('⚠️ Log não encontrado na lista!');
        return;
      }
      
      final logToRemove = currentState.todayHistory[logIndex];

      final updatedHistory = List<Map<String, dynamic>>.from(currentState.todayHistory)
        ..removeWhere((log) => log['id'] == id);

      final int amountToRemove = logToRemove['amount'] as int? ?? 0;
      final optimisticIntake = currentState.currentIntake - amountToRemove;

      final progress = currentState.dailyGoal == 0
          ? 0.0
          : (optimisticIntake / currentState.dailyGoal).clamp(0.0, 1.0);

      _updateWidget(progress, optimisticIntake, currentState.dailyGoal);

      debugPrint('✅ Emitindo novo estado: intake=$optimisticIntake, progress=$progress, history=${updatedHistory.length} items');
      
      emit(
        HomeLoaded(
          currentIntake: optimisticIntake,
          dailyGoal: currentState.dailyGoal,
          userName: currentState.userName,
          progress: progress,
          percentage: (progress * 100).toInt(),
          todayHistory: updatedHistory,
        ),
      );

      try {
        await _waterService.deleteWater(id);
        debugPrint('✅ API delete sucesso');
      } catch (e) {
        debugPrint('❌ API delete erro: $e');
        // Reverter se der erro
        emit(currentState);
        _updateWidget(
          currentState.progress,
          currentState.currentIntake,
          currentState.dailyGoal,
        );
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
