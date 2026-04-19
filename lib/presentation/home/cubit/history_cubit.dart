import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/water_service.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final WaterService _waterService;

  HistoryCubit(this._waterService) : super(HistoryInitial());

  Future<void> loadHistory({String period = '15d', String? date}) async {
    // Só mostra loading se não tiver dados ainda
    if (state is! HistoryLoaded) {
      emit(HistoryLoading());
    }

    try {
      final response = await _waterService.getHistory(
        period: period,
        date: date,
      );

      if (response != null) {
        emit(
          HistoryLoaded(
            logs: response['logs'],
            dailyGoal: response['dailyGoal'],
            stats: response['stats'],
            selectedPeriod: period,
          ),
        );
      } else if (state is! HistoryLoaded) {
        emit(HistoryError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      if (state is! HistoryLoaded) {
        emit(HistoryError('Erro ao carregar histórico: $e'));
      }
    }
  }

  Future<void> deleteWaterLog(String id) async {
    if (state is HistoryLoaded) {
      final currentState = state as HistoryLoaded;

      // Otimista: remove da lista antes de chamar API
      final updatedLogs = List<dynamic>.from(currentState.logs)
        ..removeWhere((log) => log['id'] == id);

      emit(
        HistoryLoaded(
          logs: updatedLogs,
          dailyGoal: currentState.dailyGoal,
          stats: currentState.stats,
          selectedPeriod: currentState.selectedPeriod,
        ),
      );

      try {
        await _waterService.deleteWater(id);
      } catch (e) {
        // Reverter se der erro
        emit(currentState);
      }
    }
  }

  Future<void> addWaterManual(int amount, DateTime date) async {
    try {
      final success = await _waterService.addWaterManual(amount, date);
      if (success) {
        // Pega o período atual ou usa o padrão de 30d
        final currentPeriod = state is HistoryLoaded 
            ? (state as HistoryLoaded).selectedPeriod 
            : '15d';
        await loadHistory(period: currentPeriod);
      }
    } catch (e) {
      // O ideal seria emitir um estado de erro temporário ou SnackBar
      print("Erro ao adicionar manual: $e");
    }
  }
}
