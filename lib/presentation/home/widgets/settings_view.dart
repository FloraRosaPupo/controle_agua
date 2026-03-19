import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../cubit/settings_cubit.dart';
import '../../auth/login_page.dart'; // para logout fallback ou usar go_router
import 'package:go_router/go_router.dart';
import '../../../core/api/api_client.dart'; // Caso precise limpar o token etc (ou melhor chamar AuthService)
import '../../../data/services/auth_service.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Widget _buildSectionTitle(String title, ThemeData theme, ColorScheme colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12),
      child: Text(
        title.toUpperCase(),
        style: theme.textTheme.bodySmall?.copyWith(
          letterSpacing: 1.2,
          fontWeight: FontWeight.bold,
          color: colors.onSurface.withValues(alpha: 0.5),
        ),
      ),
    );
  }

  Widget _buildProfileCard(
    ThemeData theme,
    ColorScheme colors,
    SettingsState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colors.primary, colors.primary.withValues(alpha: 0.3)],
              ),
              boxShadow: [
                BoxShadow(
                  color: colors.primary.withValues(alpha: 0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const CircleAvatar(
              radius: 30,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?u=alex'),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.name.isEmpty ? 'Usuário' : state.name,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  state.email,
                  style: theme.textTheme.bodySmall?.copyWith(
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required String settingKey,
    required ColorScheme colors,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const Spacer(),
          Switch(
            value: value,
            onChanged: (val) {
              if (settingKey == 'theme') {
                context.read<SettingsCubit>().updateSetting(
                  'theme',
                  val ? 'dark' : 'light',
                );
              } else {
                context.read<SettingsCubit>().updateSetting(settingKey, val);
              }
            },
            activeColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSection(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
    SettingsState state,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.primary.withValues(alpha: 0.1)),
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
                    "Meta de Hidratação",
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    "Defina seu objetivo diário",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
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
                  "\${state.dailyGoal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '\${m[1]}.')} ml",
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
              inactiveTrackColor: colors.primary.withValues(alpha: 0.1),
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: state.dailyGoal.clamp(500.0, 10000.0),
              min: 500,
              max: 10000,
              divisions: 38,
              onChangeEnd: (value) {
                context.read<SettingsCubit>().updateSetting('dailyGoal', value);
              },
              onChanged: (value) {
                // Aqui podemos se quiser só atualizar localmente, mas onChangeEnd bate na api.
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSliderLabel("500 ml", colors),
                _buildSliderLabel("5.000 ml", colors),
                _buildSliderLabel("10.000 ml", colors),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderLabel(String label, ColorScheme colors) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: colors.onSurface.withValues(alpha: 0.3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        if (state.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // App Bar Area (Custom)
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed: () {}, // Handled by selected index in HomePage
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Configurações",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Spacer for balance
                ],
              ),
              const SizedBox(height: 30),
              _buildProfileCard(theme, colors, state),
              _buildSectionTitle("Notificações", theme, colors),
              _buildToggleTile(
                context: context,
                icon: Icons.notifications_none_rounded,
                title: "Lembretes Diários",
                value: state.dailyReminder,
                settingKey: 'dailyReminder',
                colors: colors,
              ),
              _buildToggleTile(
                context: context,
                icon: Icons.vibration_rounded,
                title: "Vibração",
                value: state.vibration,
                settingKey: 'vibration',
                colors: colors,
              ),
              _buildSectionTitle("Meta de Hidratação", theme, colors),
              _buildGoalSection(context, theme, colors, state),
              _buildSectionTitle("Preferências", theme, colors),
              _buildToggleTile(
                context: context,
                icon: Icons.dark_mode_outlined,
                title: "Tema Visual",
                value: state.theme == 'dark',
                settingKey: 'theme',
                colors: colors,
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () async {
                  final authSvc = AuthService(ApiClient());
                  await authSvc.logout();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.error,
                  side: BorderSide(color: colors.error.withValues(alpha: 0.2)),
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  "Sair da Conta",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 120), // Bottom padding for Nav Bar
            ],
          ),
        );
      },
    );
  }
}

@Preview(name: 'Settings - Light')
Widget settingsViewLightPreview() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: const Scaffold(body: SafeArea(child: SettingsView())),
  );
}

@Preview(name: 'Settings - Dark')
Widget settingsViewDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: const Scaffold(body: SafeArea(child: SettingsView())),
  );
}
