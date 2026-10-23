import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/api/edge_functions.dart';
import '../../../core/auth/app_jwt.dart';
import 'models/daily_water_data_model.dart';

class WaterService {
  SupabaseClient get _client => Supabase.instance.client;
  static const _requestTimeout = Duration(seconds: 15);

  WaterService();

  Future<DailyWaterDataModel?> getTodayData() async {
    try {
      final response = await _client.functions
          .invoke(
            'water',
            method: HttpMethod.get,
            headers: await edgeHeadersWithAuth(),
            queryParameters: {'op': 'today'},
          )
          .timeout(_requestTimeout);
      final raw = edgeData(response);
      if (raw is! Map) {
        throw Exception('Resposta inválida');
      }
      return DailyWaterDataModel.fromJson(Map<String, dynamic>.from(raw));
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao buscar dados: $e');
    }
  }

  Future<bool> addWater(int amount) async {
    try {
      await _client.functions
          .invoke(
            'water',
            method: HttpMethod.post,
            headers: await edgeHeadersWithAuth(),
            body: {'amount': amount},
          )
          .timeout(_requestTimeout);
      return true;
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao adicionar água: $e');
    }
  }

  Future<bool> addWaterManual(int amount, DateTime date) async {
    try {
      await _client.functions
          .invoke(
            'water',
            method: HttpMethod.post,
            headers: await edgeHeadersWithAuth(),
            queryParameters: {'op': 'manual'},
            body: {'amount': amount, 'date': date.toUtc().toIso8601String()},
          )
          .timeout(_requestTimeout);
      return true;
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao adicionar registro manual: $e');
    }
  }

  Future<Map<String, dynamic>?> getHistory({
    String period = '15d',
    String? date,
  }) async {
    try {
      final qp = <String, dynamic>{'op': 'history', 'period': period};
      if (date != null) qp['date'] = date;

      final response = await _client.functions
          .invoke(
            'water',
            method: HttpMethod.get,
            headers: await edgeHeadersWithAuth(),
            queryParameters: qp,
          )
          .timeout(_requestTimeout);
      final raw = edgeData(response);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
      return null;
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao buscar histórico: $e');
    }
  }

  Future<bool> deleteWater(String id) async {
    try {
      await _client.functions
          .invoke(
            'water',
            method: HttpMethod.delete,
            headers: await edgeHeadersWithAuth(),
            queryParameters: {'id': id},
          )
          .timeout(_requestTimeout);
      return true;
    } on FunctionException catch (e) {
      if (edgeIsUnauthorized(e)) {
        await AppJwt.clear();
      }
      throw Exception(edgeErrorMessage(e));
    } catch (e) {
      throw Exception('Erro ao excluir registro: $e');
    }
  }
}
