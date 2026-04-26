import 'dart:convert';
import 'dart:io';

import 'env_key_value.dart';
import 'supabase_env.dart';

Directory? _findProjectRoot() {
  var dir = Directory.current;
  for (var i = 0; i < 24; i++) {
    if (File('${dir.path}${Platform.pathSeparator}pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) return null;
    dir = parent;
  }
  return null;
}

void _applySupabaseLocalJson(File f) {
  if (!f.existsSync()) return;
  final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  final anon = m['SUPABASE_ANON_KEY']?.toString();
  final u = m['SUPABASE_URL']?.toString();
  SupabaseEnv.applyLocalOverrides(anon: anon, url: u);
}

void tryLoadSupabaseLocalJson() {
  try {
    final root = _findProjectRoot();
    if (root == null) return;

    final sep = Platform.pathSeparator;
    final jsonFile = File('${root.path}$sep''supabase.local.json');
    if (jsonFile.existsSync()) {
      _applySupabaseLocalJson(jsonFile);
    }

    final dotEnv = File('${root.path}$sep''.env');
    if (dotEnv.existsSync()) {
      applySupabaseFromEnvText(dotEnv.readAsStringSync());
    }
  } catch (_) {}
}
