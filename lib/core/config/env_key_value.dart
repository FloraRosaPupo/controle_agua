import 'supabase_env.dart';

void applySupabaseFromEnvText(String text) {
  if (text.startsWith('\uFEFF')) text = text.substring(1);
  for (final raw in text.split('\n')) {
    var line = raw.trimRight().trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    final key = line.substring(0, eq).trim();
    var val = line.substring(eq + 1).trim();
    if (val.length >= 2 &&
        ((val.startsWith('"') && val.endsWith('"')) ||
            (val.startsWith("'") && val.endsWith("'")))) {
      val = val.substring(1, val.length - 1);
    }
    if (key == 'SUPABASE_ANON_KEY' && val.isNotEmpty) {
      SupabaseEnv.applyLocalOverrides(anon: val, url: null);
    }
    if (key == 'SUPABASE_URL' && val.isNotEmpty) {
      SupabaseEnv.applyLocalOverrides(anon: null, url: val);
    }
  }
}
