import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:home_widget/home_widget.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';
import 'core/home_widget_interactive.dart';
import 'core/services/widget_service.dart';
import 'core/config/supabase_env.dart';
import 'core/config/load_supabase_env_assets.dart';
import 'core/config/load_supabase_local_stub.dart'
    if (dart.library.io) 'core/config/load_supabase_local_io.dart'
    as supa_local;
import 'core/auth/app_jwt.dart';
import 'core/services/notification_service.dart';
import 'core/services/quick_add_offline_persist.dart';
import 'core/utils/network_error_heuristics.dart';
import 'features/hydration/data/local/user_goal_cache.dart';

import 'features/hydration/data/water_service.dart';
import 'features/auth/data/auth_service.dart';

import 'features/auth/presentation/login_page.dart';
import 'features/auth/presentation/register_page.dart';
import 'features/hydration/presentation/home_page.dart';
import 'app/splash_page.dart';
import 'features/hydration/presentation/cubit/home_cubit.dart';
import 'features/hydration/presentation/cubit/history_cubit.dart';
import 'features/auth/presentation/cubit/login_cubit.dart';
import 'features/auth/presentation/cubit/register_cubit.dart';
import 'features/hydration/presentation/cubit/settings_cubit.dart';
import 'features/hydration/presentation/cubit/notification_cubit.dart';
import 'features/hydration/data/settings_service.dart';
import 'package:flutter/foundation.dart';

import 'core/services/midnight_widget_alarm.dart';

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

Future<void> _initSupabase() async {
  if (!SupabaseEnv.hasAnonKey) {
    throw StateError(
      'SUPABASE_ANON_KEY em falta.\n'
      '• Preenche assets/env/app.env ou .env na raiz (desktop).\n'
      '• Ou flutter run --dart-define=SUPABASE_ANON_KEY=...',
    );
  }
  await Supabase.initialize(
    url: SupabaseEnv.urlResolved,
    anonKey: SupabaseEnv.anonKey,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await MidnightWidgetAlarm.ensureInitialized();
  }
  await loadSupabaseEnvFromAssets();
  supa_local.tryLoadSupabaseLocalJson();
  await AppTheme.initialize();
  await AppJwt.hydrate();
  await _initSupabase();

  if (kDebugMode) {
    Bloc.observer = AppBlocObserver();
  }

  await HomeWidget.registerInteractivityCallback(homeWidgetInteractiveCallback);

  final notificationService = NotificationService();
  await notificationService.initialize();

  final authService = AuthService();
  final waterService = WaterService();
  final settingsService = SettingsService();
  notificationService.configureQuickAddAction(
    resolveQuickAddAmount: () async {
      try {
        final data = await settingsService.getSettings();
        final raw = data['quickAddAmount'];
        if (raw is num && raw > 0) {
          final ml = raw.toInt();
          await UserGoalCache.setQuickAddMl(ml);
          return ml;
        }
      } catch (_) {}
      return UserGoalCache.getQuickAddMlOrDefault();
    },
    onQuickAdd: (ml) async {
      var fallbackGoal = await UserGoalCache.getDailyGoalMlOrDefault();
      try {
        final data = await settingsService.getSettings();
        final g = (data['dailyGoal'] as num?)?.toInt();
        if (g != null && g > 0) {
          fallbackGoal = g;
          await UserGoalCache.setDailyGoalMl(g);
        }
      } catch (_) {}

      try {
        await waterService.addWater(ml);

        final today = await waterService.getTodayData();
        if (today == null || today.dailyGoal <= 0) return;

        final percent = today.dailyGoal > 0
            ? ((today.total * 100) ~/ today.dailyGoal)
            : 0;
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
      } catch (e) {
        final queueOffline = messageSuggestsNetworkFailure(e.toString());
        if (queueOffline) {
          await persistQuickAddWaterOffline(
            amountMl: ml,
            fallbackGoalMl: fallbackGoal,
            notify: notificationService,
          );
        } else {
          await notificationService.showNotification(
            id: 8889,
            title: 'Bebeu?',
            body: 'Não foi possível registrar. Abra o app e tente de novo.',
          );
        }
      }
    },
  );

  final loggedIn = await authService.isLoggedIn();
  if (!kIsWeb) {
    await _syncWidgetWithLatestData(
      isLoggedIn: loggedIn,
      waterService: waterService,
      settingsService: settingsService,
    );
  }

  final router = GoRouter(
    refreshListenable: AppJwt.authState,
    redirect: (context, state) {
      final isLogged = AppJwt.isAuthenticated;
      final goingToHome = state.matchedLocation == '/home';
      final goingToSplash = state.matchedLocation == '/splash';
      final goingToLogin = state.matchedLocation == '/login';
      final goingToRegister = state.matchedLocation == '/register';

      if (!isLogged && goingToHome) return '/login';
      if (isLogged && (goingToSplash || goingToLogin || goingToRegister)) {
        return '/home';
      }
      return null;
    },
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/splash'),
      GoRoute(
        name: 'splash',
        path: '/splash',
        builder: (context, state) => SplashPage(isLoggedIn: loggedIn),
      ),

      GoRoute(
        name: 'login',
        path: '/login',
        builder: (context, state) => BlocProvider(
          create: (_) => LoginCubit(authService),
          child: const LoginPage(),
        ),
      ),
      GoRoute(
        name: 'register',
        path: '/register',
        builder: (context, state) => BlocProvider(
          create: (_) => RegisterCubit(authService),
          child: const RegisterPage(),
        ),
      ),
      GoRoute(
        name: 'home',
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Rota não encontrada: ${state.uri}')),
    ),
  );

  runApp(
    // MultiProvider é usado para fornecer o AuthService para toda a árvore de widgets
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
    await UserGoalCache.clear();
    await WidgetService.updateHomeWidget(
      progress: 0,
      currentIntake: 0,
      goal: 2000,
      quickAddMl: 200,
    );
    return;
  }

  try {
    final settings = await settingsService.getSettings();
    final fallbackGoal = (settings['dailyGoal'] as num?)?.toInt() ?? 2000;
    await UserGoalCache.setDailyGoalMl(fallbackGoal);
    final quickAdd = (settings['quickAddAmount'] as num?)?.toInt() ?? 200;
    await UserGoalCache.setQuickAddMl(quickAdd);
    final today = await waterService.getTodayData();

    final total = today?.total ?? 0;
    final goal = (today?.dailyGoal ?? fallbackGoal).clamp(1, 100000);
    await UserGoalCache.setDailyGoalMl(goal);
    final progress = (total / goal).clamp(0.0, 1.0);

    await WidgetService.updateHomeWidget(
      progress: progress,
      currentIntake: total,
      goal: goal,
      quickAddMl: quickAdd,
    );
  } catch (_) {
    final cachedGoal = await UserGoalCache.getDailyGoalMlOrDefault();
    final cachedQuick = await UserGoalCache.getQuickAddMlOrDefault();
    await WidgetService.updateHomeWidget(
      progress: 0,
      currentIntake: 0,
      goal: cachedGoal.clamp(1, 100000),
      quickAddMl: cachedQuick,
    );
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
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      AppJwt.authState.addListener(_syncMidnightAlarmWithAuth);
      _syncMidnightAlarmWithAuth();
    }
  }

  @override
  void dispose() {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      AppJwt.authState.removeListener(_syncMidnightAlarmWithAuth);
    }
    super.dispose();
  }

  void _syncMidnightAlarmWithAuth() {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (AppJwt.authState.value) {
      MidnightWidgetAlarm.schedule();
    } else {
      MidnightWidgetAlarm.cancel();
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
          // MaterialApp.router é usado para configurar a navegação do app
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: mode,
          routerConfig: widget
              .router, // routerConfig é usado para configurar a navegação do app
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),
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
    home: BlocProvider(
      create: (_) => LoginCubit(AuthService()),
      child: const LoginPage(),
    ),
  );
}

@Preview(name: 'App - Dark')
Widget myAppDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: BlocProvider(
      create: (_) => LoginCubit(AuthService()),
      child: const LoginPage(),
    ),
  );
}
