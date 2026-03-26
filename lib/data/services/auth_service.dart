import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';

class AuthService {
  final ApiClient _apiClient;

  AuthService(this._apiClient);

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwt_token', token);

        _apiClient.setToken(token);
      } else {
        throw Exception('Credenciais inválidas');
      }
    } on DioException catch (e) {
      // Puxando o erro do express
      throw Exception(e.response?.data['error'] ?? 'Erro de conexão no login');
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    double dailyGoal,
  ) async {
    try {
      final response = await _apiClient.dio.post(
        '/register',
        data: {
          'name': name,
          'email': email,
          'password': password,
          'dailyGoal': dailyGoal,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Sucesso no cadastro! Opcional: já logar o usuário automaticamente
        await login(email, password);
      } else {
        throw Exception('Erro ao cadastrar');
      }
    } on DioException catch (e) {
      throw Exception(
        e.response?.data['error'] ?? 'Erro de conexão no cadastro',
      );
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    _apiClient.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && token.isNotEmpty) {
      _apiClient.setToken(token);
      return true;
    }
    return false;
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '/settings/password',
        data: {
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        },
      );
      if (response.statusCode != 200) {
        throw Exception('Não foi possível alterar a senha');
      }
    } on DioException catch (e) {
      final data = e.response?.data;
      final msg = data is Map && data['error'] != null
          ? data['error'].toString()
          : 'Erro ao alterar senha';
      throw Exception(msg);
    }
  }
}
