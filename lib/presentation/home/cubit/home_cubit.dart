import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/daily_water_data_model.dart';
import '../../../data/services/water_service.dart';
import '../../../data/services/local_database_service.dart';
import '../../../data/services/connectivity_service.dart';
import '../../../core/services/widget_service.dart';
import '../../../core/services/notification_service.dart';
import 'home_state.dart';


class HomeCubit extends Cubit<HomeState> {
  final WaterService _waterService;
  final NotificationService _notificationService = NotificationService();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  bool _isOffline = false;

  HomeCubit(this._waterService) : super(HomeInitial()) {
    _connectivitySub = ConnectivityService.onConnectivityChanged.listen(
      (results) {
        final isConnected = !results.contains(ConnectivityResult.none);
        if (isConnected && _isOffline) {
          _isOffline = false;
          _syncAndReload();
        } else if (!isConnected && !_isOffline) {
          _isOffline = true;
        }
      },
    );
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel();
    return super.close();
  }

  void _emitLoadedFromModel(
    DailyWaterDataModel data, {
    bool notifyProgress = false,
  }) {
    final currentIntake = data.total;
    final dailyGoal = data.dailyGoal;

    final sortedLogs = List.of(data.logs)
      ..sort((a, b) => b.date.compareTo(a.date));

    final todayHistory = sortedLogs
        .map(
          (log) => {
            "id": log.id,
            "type": "Água",
            "amount": log.amount,
            "time": log.date.toString().substring(11, 16),
          },
        )
        .toList();

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
        syncedCount: _pendingSyncedCount,
      ),
    );

    if (notifyProgress) {
      _notificationService.checkProgressAndNotify(
        current: currentIntake,
        goal: dailyGoal,
        userName: data.name,
      );
    }

    // Salva cache local para uso offline
    LocalDatabaseService.cacheDailyData(
      totalIntake: currentIntake,
      dailyGoal: dailyGoal,
      userName: data.name,
    );
  }

  Future<void> _emitOfflineFromCache() async {
    final cached = await LocalDatabaseService.getCachedData();
    final pendingCount = await LocalDatabaseService.getPendingCount();
    final pendingAmount = await LocalDatabaseService.getPendingAmount();

    final int intake = cached?['total_intake'] as int? ?? 0;
    final int goal = cached?['daily_goal'] as int? ?? 2000;
    final String name = cached?['user_name'] as String? ?? 'Usuário';

    final progress = goal == 0 ? 0.0 : (intake / goal).clamp(0.0, 1.0);
    final percentage = (progress * 100).toInt();

    _updateWidget(progress, intake, goal);

    emit(
      HomeOffline(
        currentIntake: intake,
        dailyGoal: goal,
        userName: name,
        progress: progress,
        percentage: percentage,
        pendingCount: pendingCount,
        pendingAmount: pendingAmount,
      ),
    );
  }

  Future<void> loadTodayData() async {
    emit(HomeLoading());

    final isConnected = await ConnectivityService.isConnected();
    if (!isConnected) {
      _isOffline = true;
      await _emitOfflineFromCache();
      return;
    }

    try {
      final data = await _waterService.getTodayData();
      if (data != null) {
        _emitLoadedFromModel(data, notifyProgress: false);
      } else {
        emit(HomeError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      _isOffline = true;
      await _emitOfflineFromCache();
    }
  }

  Future<void> refreshTodayData() async {
    final isConnected = await ConnectivityService.isConnected();
    if (!isConnected) {
      _isOffline = true;
      if (state is! HomeOffline) {
        await _emitOfflineFromCache();
      }
      return;
    }

    try {
      final data = await _waterService.getTodayData();
      if (data != null) {
        _emitLoadedFromModel(data, notifyProgress: false);
      } else if (state is! HomeLoaded) {
        emit(HomeError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      if (state is! HomeLoaded && state is! HomeOffline) {
        emit(HomeError('Erro ao carregar dados: $e'));
      }
    }
  }

  Future<String?> addWater(int ml) async {
    if (ml <= 0) return null;

    // Modo offline: salva na fila local
    if (state is HomeOffline) {
      final currentState = state as HomeOffline;
      final newIntake = currentState.currentIntake + ml;
      final progress = currentState.dailyGoal == 0
          ? 0.0
          : (newIntake / currentState.dailyGoal).clamp(0.0, 1.0);

      try {
        await LocalDatabaseService.addPendingLog(ml);
        await LocalDatabaseService.updateCachedIntake(newIntake);
        final pendingCount = await LocalDatabaseService.getPendingCount();
        final pendingAmount = await LocalDatabaseService.getPendingAmount();

        _updateWidget(progress, newIntake, currentState.dailyGoal);

        emit(
          HomeOffline(
            currentIntake: newIntake,
            dailyGoal: currentState.dailyGoal,
            userName: currentState.userName,
            progress: progress,
            percentage: (progress * 100).toInt(),
            pendingCount: pendingCount,
            pendingAmount: pendingAmount,
          ),
        );

        _notificationService.checkProgressAndNotify(
          current: newIntake,
          goal: currentState.dailyGoal,
          userName: currentState.userName,
        );
        return null;
      } catch (e) {
        return "Erro ao salvar offline, tente novamente.";
      }
    }

    // Modo online: fluxo otimista normal
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

      try {
        await _waterService.addWater(ml);
        
        _notificationService.checkProgressAndNotify(
          current: optimisticIntake,
          goal: currentState.dailyGoal,
          userName: currentState.userName,
        );

        await refreshTodayData();
        return null;
      } catch (e) {
        _updateWidget(
          currentState.progress,
          currentState.currentIntake,
          currentState.dailyGoal,
        );
        emit(currentState);
        return "Sinal fraco, tente novamente.";
      }
    }

    return null;
  }

  Future<void> _syncAndReload() async {
    final pending = await LocalDatabaseService.getPendingLogs();
    if (pending.isEmpty) {
      await loadTodayData();
      return;
    }

    // Mostra o banner "sincronizando" sem sair da tela atual
    if (state is HomeOffline) {
      final s = state as HomeOffline;
      emit(HomeOffline(
        currentIntake: s.currentIntake,
        dailyGoal: s.dailyGoal,
        userName: s.userName,
        progress: s.progress,
        percentage: s.percentage,
        pendingCount: s.pendingCount,
        pendingAmount: s.pendingAmount,
        isSyncing: true,
      ));
    }

    int syncedCount = 0;
    try {
      for (final log in pending) {
        final amount = log['amount'] as int;
        final id = log['id'] as int;
        await _waterService.addWater(amount);
        await LocalDatabaseService.markLogSynced(id);
        syncedCount++;
      }
      debugPrint('✅ $syncedCount registros sincronizados');
    } catch (e) {
      debugPrint('❌ Erro ao sincronizar: $e');
    }

    _pendingSyncedCount = syncedCount;
    await loadTodayData();
    _pendingSyncedCount = 0;
  }

  int _pendingSyncedCount = 0;

  Future<void> deleteWaterLog(String id) async {
    debugPrint('🗑️ deleteWaterLog chamado com id: $id');

    if (state is HomeLoaded) {
      final currentState = state as HomeLoaded;
      debugPrint(
        '📊 Estado atual: intake=${currentState.currentIntake}, history=${currentState.todayHistory.length} items',
      );

      final logIndex = currentState.todayHistory.indexWhere(
        (log) => log['id'] == id,
      );

      if (logIndex == -1) {
        debugPrint('⚠️ Log não encontrado na lista!');
        return;
      }

      final logToRemove = currentState.todayHistory[logIndex];

      final updatedHistory = List<Map<String, dynamic>>.from(
        currentState.todayHistory,
      )..removeWhere((log) => log['id'] == id);

      final int amountToRemove = logToRemove['amount'] as int? ?? 0;
      final optimisticIntake = currentState.currentIntake - amountToRemove;

      final progress = currentState.dailyGoal == 0
          ? 0.0
          : (optimisticIntake / currentState.dailyGoal).clamp(0.0, 1.0);

      _updateWidget(progress, optimisticIntake, currentState.dailyGoal);

      debugPrint(
        '✅ Emitindo novo estado: intake=$optimisticIntake, progress=$progress, history=${updatedHistory.length} items',
      );

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
