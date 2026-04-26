import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';

Map<String, String> edgeHeaders() {
  return {
    'x-timezone-offset': DateTime.now().timeZoneOffset.inMinutes.toString(),
  };
}

dynamic edgeData(FunctionResponse response) => response.data;

String edgeErrorMessage(FunctionException e) {
  final d = e.details;
  if (d is Map) {
    if (d['error'] != null) return d['error'].toString();
    if (d['message'] != null) return d['message'].toString();
    return jsonEncode(d);
  }
  if (d is String) {
    final t = d.trim();
    if (t.isEmpty) {
      return e.reasonPhrase ?? 'Erro HTTP ${e.status}';
    }
    try {
      final j = jsonDecode(t);
      if (j is Map && j['error'] != null) return j['error'].toString();
    } catch (_) {}
    if (t.length > 200) {
      return '${t.substring(0, 200)}… (HTTP ${e.status})';
    }
    return t;
  }
  final phrase = e.reasonPhrase?.trim();
  if (phrase != null && phrase.isNotEmpty) {
    return '$phrase (HTTP ${e.status})';
  }
  return 'Erro HTTP ${e.status}';
}
