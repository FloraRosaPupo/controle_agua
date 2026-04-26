import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppJwt {
  AppJwt._();

  static const _key = 'jwt_token';

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true), //versao de armazenamento criptografado para android
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock), //versao de armazenamento criptografado para ios
  );

  static String? _memory;

  //hydrate é uma função que carrega o token do storage
  static Future<void> hydrate() async {
    final t = await _storage.read(key: _key); //le o token do storage
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
  //bearerForSupabase é uma função que retorna o token para o supabase
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

  //setFromLogin é uma função que salva o token no storage
  static Future<void> setFromLogin(String token) async {
    _memory = token;
    await _storage.write(key: _key, value: token); //salva o token no storage
  }

  //clear é uma função que limpa o token do storage
  static Future<void> clear() async {
    _memory = null;
    await _storage.delete(key: _key);
  }

  //hasValidStoredToken é uma função que verifica se o token é valido
  static Future<bool> hasValidStoredToken() async {
    final t = await bearerForSupabase();
    return t != null && t.isNotEmpty;
  }

  //_jwtExpired é uma função que verifica se o token expirou
  static bool _jwtExpired(String token) {
    try {
      final parts = token.split('.');
      //verifica se o token tem 3 partes-> header, payload e signature
      if (parts.length != 3) return true;
      final normalized = base64Url.normalize(parts[1]); //normaliza o payload
      final map = jsonDecode(utf8.decode(base64Url.decode(normalized))) //decodifica o payload
          as Map<String, dynamic>;
      final exp = map['exp']; //pega o tempo de expiração do token
      if (exp is! num) return false;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000; //pega o tempo atual em segundos
      return nowSec >= exp.toInt();
    } catch (_) {
      return true;
    }
  }
}
