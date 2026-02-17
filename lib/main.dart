import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'core/theme/app_theme.dart';
import 'presentation/auth/login_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const LoginPage(),
    );
  }
}

@Preview(name: 'App - Light')
Widget myAppLightPreview() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: const LoginPage(),
  );
}

@Preview(name: 'App - Dark')
Widget myAppDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: const LoginPage(),
  );
}
