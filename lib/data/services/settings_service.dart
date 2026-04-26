import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/api/edge_functions.dart';
import '../../core/auth/app_jwt.dart';

class SettingsService {
  SupabaseClient get _client => Supabase.instance.client;

  SettingsService();

  Future<Map<String, dynamic>> getSettings() async {
    try {
      final response = await _client.functions.invoke(
        'settings',
        method: HttpMethod.get,
        headers: await edgeHeadersWithAuth(),
      );
      final raw = edgeData(response);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      throw Exception('Resposta inválida');
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao buscar configurações: $e');
    }
  }

  Future<void> updateSettings(Map<String, dynamic> data) async {
    try {
      await _client.functions.invoke(
        'settings',
        method: HttpMethod.put,
        headers: await edgeHeadersWithAuth(),
        body: data,
      );
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao atualizar configurações: $e');
    }
  }
}
