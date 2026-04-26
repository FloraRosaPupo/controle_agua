import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppJwt {
  AppJwt._();

  static const _key = 'jwt_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static String? _memory;

  static Future<void> hydrate() async {
    final t = await _storage.read(key: _key);
    if (t == null || t.isEmpty) {
      _memory = null;
      return;
    }
    if (_jwtExpired(t)) {
      await clear();
      return;
    }
    _memory = t;
  }

  static Future<String?> bearerForSupabase() async {
    if (_memory != null && _memory!.isNotEmpty) {
      if (_jwtExpired(_memory!)) {
        await clear();
        return null;
      }
      return _memory;
    }
    final t = await _storage.read(key: _key);
    if (t == null || t.isEmpty) return null;
    if (_jwtExpired(t)) {
      await clear();
      return null;
    }
    _memory = t;
    return t;
  }

  static Future<void> setFromLogin(String token) async {
    _memory = token;
    await _storage.write(key: _key, value: token);
  }

  static Future<void> clear() async {
    _memory = null;
    await _storage.delete(key: _key);
  }

  static Future<bool> hasValidStoredToken() async {
    final t = await bearerForSupabase();
    return t != null && t.isNotEmpty;
  }

  static bool _jwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]);
      final map = jsonDecode(utf8.decode(base64Url.decode(normalized)))
          as Map<String, dynamic>;
      final exp = map['exp'];
      if (exp is! num) return false;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return nowSec >= exp.toInt();
    } catch (_) {
      return true;
    }
  }
}
