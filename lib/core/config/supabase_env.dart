import 'supabase_env_stub.dart'
    if (dart.library.io) 'supabase_env_io.dart' as supa_platform;

/// URL e chave anon do projeto Supabase (Edge Functions, etc.).
class SupabaseEnv {
  SupabaseEnv._();

  static String? _runtimeAnon;
  static String? _runtimeUrl;

  static void applyLocalOverrides({String? anon, String? url}) {
    if (anon != null && anon.isNotEmpty) _runtimeAnon = anon;
    if (url != null && url.isNotEmpty) _runtimeUrl = url;
  }

  static const String _urlFromDefine = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const String _defaultProjectUrl =
      'https://nbyshvpapwvewhwggest.supabase.co';

  static const String _anonFromDefine = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
  defaultValue:
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5ieXNodnBhcHd2ZXdod2dnZXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE5NjY2NTksImV4cCI6MjA4NzU0MjY1OX0.yDlG835MsC8pERfQBurUbBBjqkGJVF7OsoqpmIoKMPw',
  );

  static String get urlResolved {
    if (_urlFromDefine.isNotEmpty) return _urlFromDefine;
    if (_runtimeUrl != null && _runtimeUrl!.isNotEmpty) return _runtimeUrl!;
    return _defaultProjectUrl;
  }

  static String get anonKey {
    if (_anonFromDefine.isNotEmpty) return _anonFromDefine;
    final p = supa_platform.supabaseAnonFromPlatform();
    if (p != null && p.isNotEmpty) return p;
    if (_runtimeAnon != null && _runtimeAnon!.isNotEmpty) return _runtimeAnon!;
    return '';
  }

  static bool get hasAnonKey => anonKey.isNotEmpty;
}
