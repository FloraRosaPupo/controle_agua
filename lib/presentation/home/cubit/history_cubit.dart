import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/water_service.dart';
import 'history_state.dart';

class HistoryCubit extends Cubit<HistoryState> {
  final WaterService _waterService;

  HistoryCubit(this._waterService) : super(HistoryInitial());

  Future<void> loadHistory({String period = '7d', String? date}) async {
    emit(HistoryLoading());

    try {
      final response = await _waterService.getHistory(period: period, date: date);
      
      if (response != null) {
        emit(HistoryLoaded(
          logs: response['logs'],
          dailyGoal: response['dailyGoal'],
          stats: response['stats'],
          selectedPeriod: period,
        ));
      } else {
        emit(HistoryError("Nenhum dado retornado da API."));
      }
    } catch (e) {
      emit(HistoryError('Erro ao carregar histórico: $e'));
    }
  }
}
