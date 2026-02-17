import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:home_widget/home_widget.dart';
import 'core/theme/app_theme.dart';
import 'core/services/widget_service.dart';
import 'presentation/auth/login_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Atualiza widget ao instalar/abrir app (mostra conteúdo mesmo antes de logar)
  WidgetService.updateHomeWidget(
    progress: 0,
    currentIntake: 0,
    goal: 2000,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    // Escuta quando o usuário clica no widget
    HomeWidget.widgetClicked.listen(_launchedFromWidget);
    _checkForWidgetLaunch();
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null) {
      // Aqui você pode navegar para uma tela específica se o widget enviar um URI
      debugPrint('App aberto pelo widget: $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          home: const LoginPage(),
        );
      },
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
