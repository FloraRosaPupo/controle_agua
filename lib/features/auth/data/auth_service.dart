import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/edge_functions.dart';
import '../../../core/auth/app_jwt.dart';

class AuthService {
  SupabaseClient get _client => Supabase.instance.client;

  AuthService();

  Future<void> login(String email, String password) async {
    try {
      final response = await _client.functions.invoke(
        'auth-login',
        method: HttpMethod.post,
        headers: edgeHeaders(),
        body: {'email': email, 'password': password},
      );
      final raw = edgeData(response);
      if (raw is! Map || raw['token'] == null) {
        throw Exception('Resposta de login inválida');
      }
      await AppJwt.setFromLogin(raw['token'].toString());
    } on FunctionException catch (e) {
      final msg = edgeErrorMessage(e);
      if (kDebugMode) {
        debugPrint(
          '[auth-login] status=${e.status} details=${e.details} → $msg',
        );
      }
      throw Exception(msg);
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro de conexão no login: $e');
    }
  }

  Future<void> register(
    String name,
    String email,
    String password,
    double dailyGoal,
  ) async {
    try {
      final response = await _client.functions.invoke(
        'auth-register',
        method: HttpMethod.post,
        headers: edgeHeaders(),
        body: {
          'name': name,
          'email': email,
          'password': password,
          'dailyGoal': dailyGoal.round(),
        },
      );
      final raw = edgeData(response);
      if (raw is! Map || raw['token'] == null) {
        throw Exception('Resposta de cadastro inválida');
      }
      await AppJwt.setFromLogin(raw['token'].toString());
    } on FunctionException catch (e) {
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro de conexão no cadastro: $e');
    }

    final goal = dailyGoal.round();
    if (goal > 0 && goal != 2000) {
      try {
        await _client.functions.invoke(
          'settings',
          method: HttpMethod.put,
          headers: await edgeHeadersWithAuth(),
          body: {'dailyGoal': goal},
        );
      } catch (_) {}
    }
  }

  Future<void> logout() async {
    await AppJwt.clear();
  }

  Future<bool> isLoggedIn() => AppJwt.hasValidStoredToken();

  //changePassword é uma função que altera a senha do usuário
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _client.functions.invoke(
        'settings',
        method: HttpMethod.put,
        headers: await edgeHeadersWithAuth(),
        queryParameters: {'op': 'password'},
        body: {'currentPassword': currentPassword, 'newPassword': newPassword},
      );
    } on FunctionException catch (e) {
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Erro de conexão: $e');
    }
  }
}
