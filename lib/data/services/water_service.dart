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
        return response.data;
      }
      return null;
    } on DioException catch (e) {
      throw Exception(
        'Erro ao buscar histórico: ${e.response?.data['error'] ?? e.message}',
      );
    }
  }

  Future<bool> deleteWater(String id) async {
    try {
      final response = await _apiClient.dio.delete('/water/$id');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception(
        'Erro ao excluir registro: ${e.response?.data['error'] ?? e.message}',
      );
    }
  }
}

