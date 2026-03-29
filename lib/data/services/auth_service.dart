import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../core/api/api_client.dart';

class AuthService {
  final ApiClient _apiClient;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );
  static const _tokenKey = 'jwt_token';

  AuthService(this._apiClient);

  Future<void> login(String email, String password) async {
    try {
      final response = await _apiClient.dio.post(
        '/login',
        data: {'email': email, 'password': password},
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];

        await _storage.write(key: _tokenKey, value: token);

        _apiClient.setToken(token);
      } else {
        throw Exception('Credenciais inválidas');
      }
    } on DioException catch (e) {
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
    await _storage.delete(key: _tokenKey);
    _apiClient.clearToken();
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
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
