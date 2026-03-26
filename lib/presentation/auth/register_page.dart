import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../core/theme/app_theme.dart';
import '../../controllers/register_controller.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_assets.dart';
import 'cubit/register_cubit.dart';
import 'cubit/register_state.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  bool _isPasswordVisible = false;
  double _dailyGoal = 2500;
  final _controller = RegisterController();
  Timer? _loadingTimer;
  int _loadingSeconds = 0;

  void _onRegisterStateChanged(RegisterState state) {
    if (state is RegisterLoading) {
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
    final textTheme = theme.textTheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.scaffoldBackgroundColor,
              theme.scaffoldBackgroundColor.withValues(alpha: 0.8),
            ],
          ),
        ),
        child: SafeArea(
          child: BlocListener<RegisterCubit, RegisterState>(
            listener: (context, state) {
              _onRegisterStateChanged(state);
              if (state is RegisterSuccess) {
                context.go('/home');
              } else if (state is RegisterFailure) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.error),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Top Bar: Logo + App Name
                  Row(
                    children: [
                      Image.asset(
                        AppAssets.logo,
                        height: 80,
                        fit: BoxFit.contain,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "bebeu",
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                  // Headlines
                  Text(
                    "Comece sua jornada",
                    style: textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Hidrate-se melhor, sinta-se melhor.",
                    style: textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Form
                  _buildFieldLabel(context, "NOME COMPLETO"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller.nameController,
                    decoration: InputDecoration(
                      hintText: "Seu nome",
                      prefixIcon: Icon(
                        Icons.person_outline,
                        color: colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildFieldLabel(context, "E-MAIL"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller.emailController,
                    decoration: InputDecoration(
                      hintText: "seu@email.com",
                      prefixIcon: Icon(
                        Icons.alternate_email,
                        color: colors.primary.withValues(alpha: 0.5),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildFieldLabel(context, "SENHA"),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller.passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      hintText: "••••••••",
                      prefixIcon: Icon(
                        Icons.lock_outline,
                        color: colors.primary.withValues(alpha: 0.5),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility
                              : Icons.visibility_off,
                          color: colors.primary.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Initial Goal Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.1),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Definir sua meta inicial",
                                  style: textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "Pode ser alterada depois",
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colors.onSurface.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: colors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _controller.formatDailyGoal(_dailyGoal),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: colors.primary,
                            inactiveTrackColor: colors.primary.withValues(
                              alpha: 0.1,
                            ),
                            thumbColor: colors.primary,
                            overlayColor: colors.primary.withValues(alpha: 0.2),
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: _dailyGoal.clamp(500.0, 5000.0),
                            min: 500,
                            max: 5000,
                            divisions: 18, // passos de 250 ml (4500 / 250)
                            onChanged: (value) =>
                                setState(() => _dailyGoal = value),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSliderLabel("500 ml"),
                              _buildSliderLabel("2.750 ml"),
                              _buildSliderLabel("5.000 ml"),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Register Button
                  BlocBuilder<RegisterCubit, RegisterState>(
                    builder: (context, state) {
                      return ElevatedButton(
                        onPressed: state is RegisterLoading
                            ? null
                            : () {
                                final name = _controller.nameController.text
                                    .trim();
                                final email = _controller.emailController.text
                                    .trim();
                                final pwd = _controller.passwordController.text;

                                if (name.isNotEmpty &&
                                    email.isNotEmpty &&
                                    pwd.isNotEmpty) {
                                  context
                                      .read<RegisterCubit>()
                                      .registerAndLogin(
                                        name,
                                        email,
                                        pwd,
                                        _dailyGoal,
                                      );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Preencha todos os campos.",
                                      ),
                                    ),
                                  );
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.primary,
                          foregroundColor: Colors.white,
                          minimumSize: Size(
                            double.infinity,
                            state is RegisterLoading ? 88 : 56,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 8,
                          shadowColor: colors.primary.withValues(alpha: 0.4),
                        ),
                        child: state is RegisterLoading
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _loadingSeconds == 0
                                        ? 'Carregando'
                                        : 'Carregando',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              )
                            : const Text(
                                "Criar Conta",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Já tem uma conta? ",
                        style: textTheme.bodyMedium?.copyWith(
                          color: colors.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          "Entrar",
                          style: TextStyle(
                            color: colors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Ao se registrar, você concorda com nossos Termos de Serviço e Política de Privacidade.",
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: colors.onSurface.withValues(alpha: 0.4),
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

  Widget _buildFieldLabel(BuildContext context, String label) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        letterSpacing: 1.2,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
      ),
    );
  }

  Widget _buildSliderLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
      ),
    );
  }
}

@Preview(name: 'Register Page - Light')
Widget registerPageLightPreview() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: const RegisterPage(),
  );
}

@Preview(name: 'Register Page - Dark')
Widget registerPageDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: const RegisterPage(),
  );
}
