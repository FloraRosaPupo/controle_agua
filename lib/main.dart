import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/home_widget_interactive.dart';
import 'core/services/widget_service.dart';
import 'core/api/api_client.dart';
import 'core/services/notification_service.dart';

import 'data/services/water_service.dart';
import 'data/services/auth_service.dart';

import 'presentation/auth/login_page.dart';
import 'presentation/auth/register_page.dart';
import 'presentation/home/home_page.dart';
import 'presentation/splash/splash_page.dart';
import 'presentation/home/cubit/home_cubit.dart';
import 'presentation/home/cubit/history_cubit.dart';
import 'presentation/auth/cubit/login_cubit.dart';
import 'presentation/auth/cubit/register_cubit.dart';
import 'presentation/home/cubit/settings_cubit.dart';
import 'presentation/home/cubit/notification_cubit.dart';
import 'data/services/settings_service.dart';
import 'package:flutter/foundation.dart'; // import para kIsWeb

class AppBlocObserver extends BlocObserver {
  @override
  void onChange(BlocBase bloc, Change change) {
    super.onChange(bloc, change);
    debugPrint('🔄 ${bloc.runtimeType} changed');
    debugPrint('   Current: ${change.currentState.runtimeType}');
    debugPrint('   Next: ${change.nextState.runtimeType}');
  }

  @override
  void onError(BlocBase bloc, Object error, StackTrace stackTrace) {
    debugPrint('❌ ${bloc.runtimeType} error: $error');
    super.onError(bloc, error, stackTrace);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppTheme.initialize();

  // Ativa o observer para debugar estados (apenas em debug)
  if (kDebugMode) {
    Bloc.observer = AppBlocObserver();
  }

  await HomeWidget.registerInteractivityCallback(homeWidgetInteractiveCallback);

  final notificationService = NotificationService();
  await notificationService.initialize();

  final apiClient = ApiClient();
  final authService = AuthService(apiClient);
  final waterService = WaterService(apiClient);
  final settingsService = SettingsService(apiClient);
  notificationService.configureQuickAddAction(
    resolveQuickAddAmount: () async {
      final data = await settingsService.getSettings();
      final raw = data['quickAddAmount'];
      if (raw is num && raw > 0) return raw.toInt();
      return 200;
    },
    onQuickAdd: (ml) async {
      final added = await waterService.addWater(ml);
      if (!added) return;

      final today = await waterService.getTodayData();
      if (today == null || today.dailyGoal <= 0) return;

      final percent = ((today.total / today.dailyGoal) * 100).toInt().clamp(
        0,
        100,
      );
      final status = 'Você adicionou ${ml}ml';
      await notificationService.showProgressNotification(
        id: 995,
        title: '+${ml}ml registrado ✅',
        currentMl: today.total,
        goalMl: today.dailyGoal,
        percent: percent,
        statusText: status,
        ongoing: false,
      );
    },
  );

  // Verifica se temos token localmente antes de decidir a tela principal!
  final loggedIn = await authService.isLoggedIn();
  if (!kIsWeb) {
    await _syncWidgetWithLatestData(
      isLoggedIn: loggedIn,
      waterService: waterService,
      settingsService: settingsService,
    );
  }

  final router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => SplashPage(isLoggedIn: loggedIn),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => BlocProvider(
          create: (_) => LoginCubit(authService),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => BlocProvider(
          create: (_) => RegisterCubit(authService),
          child: const RegisterPage(),
        ),
      ),
      GoRoute(path: '/home', builder: (context, state) => const HomePage()),
    ],
  );

  runApp(
    MultiProvider(
      providers: [RepositoryProvider<AuthService>.value(value: authService)],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(create: (_) => HomeCubit(waterService)..loadTodayData()),
          BlocProvider(
            create: (_) => HistoryCubit(waterService)..loadHistory(),
          ),
          BlocProvider(
            create: (_) => SettingsCubit(settingsService)..loadSettings(),
          ),
          BlocProvider(
            create: (_) =>
                NotificationCubit(settingsService)..loadPreferences(),
          ),
        ],
        child: MyApp(router: router),
      ),
    ),
  );
}

Future<void> _syncWidgetWithLatestData({
  required bool isLoggedIn,
  required WaterService waterService,
  required SettingsService settingsService,
}) async {
  if (!isLoggedIn) {
    await WidgetService.updateHomeWidget(progress: 0, currentIntake: 0, goal: 2000);
    return;
  }

  try {
    final settings = await settingsService.getSettings();
    final fallbackGoal = (settings['dailyGoal'] as num?)?.toInt() ?? 2000;
    final today = await waterService.getTodayData();

    final total = today?.total ?? 0;
    final goal = (today?.dailyGoal ?? fallbackGoal).clamp(1, 100000);
    final progress = (total / goal).clamp(0.0, 1.0);

    await WidgetService.updateHomeWidget(
      progress: progress,
      currentIntake: total,
      goal: goal,
    );
  } catch (_) {
    await WidgetService.updateHomeWidget(progress: 0, currentIntake: 0, goal: 2000);
  }
}

class MyApp extends StatefulWidget {
  final GoRouter router;
  const MyApp({super.key, required this.router});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      HomeWidget.widgetClicked.listen(_launchedFromWidget);
      _checkForWidgetLaunch();
    }
  }

  void _checkForWidgetLaunch() {
    HomeWidget.initiallyLaunchedFromHomeWidget().then(_launchedFromWidget);
  }

  void _launchedFromWidget(Uri? uri) {
    if (uri != null) {
      debugPrint('App aberto pelo widget: $uri');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.themeMode,
      builder: (context, mode, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: widget.router,
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
