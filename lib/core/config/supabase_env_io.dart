import 'dart:io' show Platform;

String? supabaseAnonFromPlatform() => Platform.environment['SUPABASE_ANON_KEY'];
