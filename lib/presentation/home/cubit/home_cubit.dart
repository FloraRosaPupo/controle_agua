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
  bool _isLoadingToday = false;

  HomeCubit(this._waterService) : super(HomeInitial()) {
    _connectivitySub = ConnectivityService.onConnectivityChanged.listen(
      //listen ele serve praescutar o stream de conexão e disparar eventos quando a conexão muda
      (results) {
        final isConnected = !results.contains(ConnectivityResult.none);
        if (isConnected && _isOffline) {
          _isOffline = false; //se estiver conectado e offline, seta o offline para false
          _syncAndReload(); //sincroniza os logs não sincronizados
        } else if (!isConnected && !_isOffline) {
          _isOffline = true; //se não estiver conectado e online, seta o offline para true
        }
      },
    ); //listen ele serve pra escutar o stream de conexão e disparar eventos quando a conexão muda
  }

  @override
  Future<void> close() {
    _connectivitySub?.cancel(); //cancela o stream de conexão
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
          (log) {
            // log.date já vem em horário local no model (WaterLogModel.fromJson).
            final hh = log.date.hour.toString().padLeft(2, '0');
            final mm = log.date.minute.toString().padLeft(2, '0');
            return {
            "id": log.id,
            "type": "Água",
            "amount": log.amount,
            "time": '$hh:$mm',
          };
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

//emite o estado HomeOffline a partir dos dados do cache local
  Future<void> _emitOfflineFromCache() async {
    final cached = await LocalDatabaseService.getCachedData(); //pega os dados da tabela cached_data
    final pendingCount = await LocalDatabaseService.getPendingCount(); //pega a quantidade de logs não sincronizados
    final pendingAmount = await LocalDatabaseService.getPendingAmount(); //pega a quantidade total de ml não sincronizados

    final int intake = cached?['total_intake'] as int? ?? 0; //pega o total de ml ingeridos
    final int goal = cached?['daily_goal'] as int? ?? 2000; //pega a meta de ml diária
    final String name = cached?['user_name'] as String? ?? 'Usuário'; //pega o nome do usuário

    final progress = goal == 0 ? 0.0 : (intake / goal).clamp(0.0, 1.0); //pega o progresso
    final percentage = (progress * 100).toInt(); //pega o percentual

    _updateWidget(progress, intake, goal); //atualiza o widget

    emit(
      HomeOffline( //emite o estado HomeOffline
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
    if (_isLoadingToday) return;
    _isLoadingToday = true;
    emit(HomeLoading());

    try {
      final isConnected = await ConnectivityService.isConnected();
      if (!isConnected) {
        _isOffline = true;
        await _emitOfflineFromCache();
        return;
      }

      final data = await _waterService.getTodayData();
      if (data != null) {
        _emitLoadedFromModel(data, notifyProgress: false);
      } else {
        emit(HomeError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      debugPrint('Erro loadTodayData: $e');
      emit(HomeError('Erro ao carregar dados: $e'));
    } finally {
      _isLoadingToday = false;
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
      debugPrint('Erro refreshTodayData: $e');
      if (state is! HomeLoaded && state is! HomeOffline) {
        emit(HomeError('Erro ao carregar dados: $e'));
      }
    }
  }

  Future<String?> addWater(int ml) async {
    if (ml <= 0) return null;

    // Modo offline: salva na fila local
    if (state is HomeOffline) {
      final currentState = state as HomeOffline; //pega o estado atual
      final newIntake = currentState.currentIntake + ml; //pega o total de ml ingeridos
      final progress = currentState.dailyGoal == 0
          ? 0.0 //se a meta de ml diária for 0, o progresso é 0
          : (newIntake / currentState.dailyGoal).clamp(0.0, 1.0);

      try {
        await LocalDatabaseService.addPendingLog(ml); //insere o log na tabela pending_logs
        await LocalDatabaseService.updateCachedIntake(newIntake); //atualiza o total de ml ingeridos na tabela cached_data
        final pendingCount = await LocalDatabaseService.getPendingCount(); //pega a quantidade de logs não sincronizados
        final pendingAmount = await LocalDatabaseService.getPendingAmount(); //pega a quantidade total de ml não sincronizados

        _updateWidget(progress, newIntake, currentState.dailyGoal); //atualiza o widget

        emit(
          HomeOffline( //emite o estado HomeOffline
            currentIntake: newIntake,
            dailyGoal: currentState.dailyGoal,
            userName: currentState.userName,
            progress: progress,
            percentage: (progress * 100).toInt(),
            pendingCount: pendingCount,
            pendingAmount: pendingAmount,
          ),
        );

        _notificationService.checkProgressAndNotify( //verifica o progresso e envia uma notificação
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
        // Se o POST funcionou, não devemos exibir "Sinal fraco" por falha
        // apenas na recarga dos dados.
        try {
          await refreshTodayData();
        } catch (e) {
          debugPrint('Erro ao atualizar dados após addWater: $e');
        }
        return null;
      } catch (e) {
        _updateWidget(
          currentState.progress,
          currentState.currentIntake,
          currentState.dailyGoal,
        );
        emit(currentState);
        final msg = e.toString().toLowerCase();
        if (msg.contains('timeout')) {
          return "Bebeu não está respondendo agora. Tente em instantes.";
        }
        if (msg.contains('erro http 5') ||
            msg.contains('internal') ||
            msg.contains('server')) {
          return "Servidor indisponível no momento. Tente novamente.";
        }
        return "Falha ao adicionar agora. Tente novamente.";
      }
    }

    return null;
  }

//sincroniza os logs não sincronizados
  Future<void> _syncAndReload() async {
    final pending = await LocalDatabaseService.getPendingLogs(); //pega os logs não sincronizados
    if (pending.isEmpty) {
      await loadTodayData(); //carrega os dados da API
      return;
    }

    // Mostra o banner "sincronizando" sem sair da tela atual
    if (state is HomeOffline) {
      final s = state as HomeOffline; //pega o estado atual
      emit(HomeOffline( //emite o estado HomeOffline
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

    int syncedCount = 0; //quantidade de logs sincronizados
    try {
      for (final log in pending) {
        final amount = log['amount'] as int; //pega a quantidade de ml ingeridos
        final id = log['id'] as int; //pega o id do log
        await _waterService.addWater(amount); //insere o log na API
        await LocalDatabaseService.markLogSynced(id); //marca o log como sincronizado
        syncedCount++;
      }
      debugPrint('✅ $syncedCount registros sincronizados');
    } catch (e) {
      debugPrint('❌ Erro ao sincronizar: $e');
    }

    _pendingSyncedCount = syncedCount; //atualiza a quantidade de logs sincronizados
    await loadTodayData(); //carrega os dados da API
    _pendingSyncedCount = 0; //reseta a quantidade de logs sincronizados
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
