import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';

class SettingsService {
  final ApiClient _apiClient;

  SettingsService(this._apiClient);

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _apiClient.dio.get('/settings');
      return response.data;
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['error'] ?? 'Erro ao buscar configurações',
      );
    }
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    try {
      await _apiClient.dio.put('/settings', data: data);
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['error'] ?? 'Erro ao atualizar configurações',
      );
    }
  }
}
