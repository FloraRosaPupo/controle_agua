import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../models/daily_water_data_model.dart';

class WaterService {
  final ApiClient _apiClient;

  WaterService(this._apiClient);

  Future<DailyWaterDataModel?> getTodayData() async {
    try {
      final response = await _apiClient.dio.get('/water/today');
      if (response.statusCode == 200) {
        return DailyWaterDataModel.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      throw Exception(
        'Erro ao buscar dados: ${e.response?.data['error'] ?? e.message}',
      );
    }
  }

  Future<bool> addWater(int amount) async {
    try {
      final response = await _apiClient.dio.post(
        '/water',
        data: {'amount': amount},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(
        'Erro ao adicionar água: ${e.response?.data['error'] ?? e.message}',
      );
    }
  }
  Future<Map<String, dynamic>?> getHistory({String period = '7d', String? date}) async {
    try {
      final response = await _apiClient.dio.get(
        '/water/history',
        queryParameters: date != null ? {'date': date} : {'period': period},
      );
      if (response.statusCode == 200) {
        // Se a resposta for uma Lista (bug de cache/versão antiga no backend), 
        // a gente encapsula num mapa para não quebrar o frontend.
        if (response.data is List) {
          return {
            'logs': response.data,
            'dailyGoal': 2000,
            'stats': {
              'average': 0,
              'goalsMet': 0,
              'totalDays': period == '30d' ? 30 : 7,
            }
          };
        }
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw Exception(
        'Erro ao buscar histórico: ${e.response?.data['error'] ?? e.message}',
      );
    }
  }
}
