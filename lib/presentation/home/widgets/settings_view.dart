import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import '../../../core/theme/app_theme.dart';
import '../../../controllers/settings_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final _controller = SettingsController();

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

  Widget _buildProfileCard(ThemeData theme, ColorScheme colors) {
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _controller.userName,
                style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: 4),
              Text(
                _controller.planName,
                style: theme.textTheme.bodySmall?.copyWith(
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
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
            onChanged: onChanged,
            activeColor: colors.primary,
            activeTrackColor: colors.primary.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalSection(ThemeData theme, ColorScheme colors) {
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
                  "${_controller.dailyGoal.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} ml",
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
              value: _controller.dailyGoal,
              min: _controller.minGoal,
              max: _controller.maxGoal,
              divisions: 16, // Assuming 250ml steps for 1000-5000 range
              onChanged: (value) {
                setState(() => _controller.updateGoal(value));
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildSliderLabel("${_controller.minGoal.toInt()} ml", colors),
                _buildSliderLabel("2.500 ml", colors),
                _buildSliderLabel("${_controller.maxGoal.toInt()} ml", colors),
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
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 48), // Spacer for balance
            ],
          ),
          const SizedBox(height: 30),
          _buildProfileCard(theme, colors),
          _buildSectionTitle("Notificações", theme, colors),
          _buildToggleTile(
            icon: Icons.notifications_none_rounded,
            title: "Lembretes Diários",
            value: _controller.dailyReminders,
            onChanged: (val) =>
                setState(() => _controller.toggleReminders(val)),
            colors: colors,
          ),
          _buildToggleTile(
            icon: Icons.vibration_rounded,
            title: "Vibração",
            value: _controller.vibration,
            onChanged: (val) =>
                setState(() => _controller.toggleVibration(val)),
            colors: colors,
          ),
          _buildSectionTitle("Meta de Hidratação", theme, colors),
          _buildGoalSection(theme, colors),
          _buildSectionTitle("Preferências", theme, colors),

          _buildToggleTile(
            icon: Icons.dark_mode_outlined,
            title: "Tema Visual",
            value: _controller.isDarkMode,
            onChanged: (val) => setState(() => _controller.toggleTheme(val)),
            colors: colors,
          ),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: () {},
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
