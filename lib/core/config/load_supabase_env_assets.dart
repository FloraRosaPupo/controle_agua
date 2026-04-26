import 'package:flutter/services.dart';

import 'env_key_value.dart';

Future<void> loadSupabaseEnvFromAssets() async {
  try {
    final text = await rootBundle.loadString('assets/env/app.env');
    applySupabaseFromEnvText(text);
  } catch (_) {}
}
