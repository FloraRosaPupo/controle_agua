import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../core/theme/app_theme.dart';
import '../../controllers/login_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'cubit/login_cubit.dart';
import 'cubit/login_state.dart';
import '../../data/services/auth_service.dart';
import '../home/cubit/notification_cubit.dart';
import '../home/cubit/settings_cubit.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_assets.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _controller = LoginController();
  Timer? _loadingTimer;
  int _loadingSeconds = 0;

  void _onLoginStateChanged(LoginState state) {
    if (state is LoginLoading) {
      _loadingTimer?.cancel();
      setState(() => _loadingSeconds = 0);
      _loadingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _loadingSeconds++);
      });
    } else {
      _loadingTimer?.cancel();
      _loadingTimer = null;
      if (_loadingSeconds != 0 && mounted) {
        setState(() => _loadingSeconds = 0);
      }
    }
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: BlocListener<LoginCubit, LoginState>(
          listener: (context, state) {
            _onLoginStateChanged(state);
            if (state is LoginSuccess) {
              // Token acaba de ser definido; recarrega settings do banco e agenda notificações.
              context.read<NotificationCubit>().loadPreferences();
              context.read<SettingsCubit>().loadSettings();
              context.go('/home');
            } else if (state is LoginFailure) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.error),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),

                  // Logo / Título
                  Center(
                    child: Column(
                      children: [
                        Image.asset(
                          AppAssets.logo,
                          height: 100,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 16),
                        Text("bebeu", style: theme.textTheme.headlineLarge),
                        const SizedBox(height: 8),
                        Text(
                          "Mantenha-se hidratado todos os dias.",
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 60),

                  Text("Bem-vindo de volta", style: theme.textTheme.titleLarge),

                  const SizedBox(height: 32),

                  Text(
                    "E-MAIL",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _controller.emailController,
                    decoration: InputDecoration(
                      hintText: "seu@email.com",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "SENHA",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),

                  TextField(
                    controller: _controller.passwordController,
                    obscureText: !_controller.isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "••••••••",
                      hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _controller.togglePasswordVisibility(() {
                            setState(() {});
                          });
                        },
                        icon: Icon(
                          _controller.isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  const SizedBox(height: 24),

                  BlocBuilder<LoginCubit, LoginState>(
                    builder: (context, state) {
                      return SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: state is LoginLoading
                              ? null
                              : () {
                                  final email = _controller.emailController.text
                                      .trim();
                                  final pwd =
                                      _controller.passwordController.text;
                                  if (email.isNotEmpty && pwd.isNotEmpty) {
                                    context.read<LoginCubit>().login(
                                      email,
                                      pwd,
                                    );
                                  }
                                },
                          child: state is LoginLoading
                              ? const Text("Carregando...")
                              : const Text(
                                  "Entrar",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  Center(
                    child: TextButton(
                      onPressed: () => context.push('/register'),
                      child: const Text("Ainda não tem conta? Cadastre-se"),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

@Preview(name: 'Login Page - Light')
Widget loginPageLightPreview() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: BlocProvider(
      create: (_) => LoginCubit(AuthService(ApiClient())),
      child: const LoginPage(),
    ),
  );
}

@Preview(name: 'Login Page - Dark')
Widget loginPageDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: BlocProvider(
      create: (_) => LoginCubit(AuthService(ApiClient())),
      child: const LoginPage(),
    ),
  );
}
