import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/notification_cubit.dart';
import '../../../../core/models/notification_preferences.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() => _NotificationSettingsViewState();
}

class _NotificationSettingsViewState extends State<NotificationSettingsView> {
  @override
  void initState() {
    super.initState();
    context.read<NotificationCubit>().loadPreferences();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text("Configurações de Alerta"),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: BlocBuilder<NotificationCubit, NotificationState>(
        builder: (context, state) {
          if (state is NotificationLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is NotificationError) {
            return Center(child: Text(state.message));
          } else if (state is NotificationLoaded) {
            final prefs = state.prefs;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader(theme, colors, "GERAL"),
                  _buildSwitchTile(
                    theme,
                    colors,
                    "Ativar Notificações",
                    "Receber lembretes de hidratação",
                    prefs.enabled,
                    (val) => _updatePrefs(prefs.copyWith(enabled: val)),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, colors, "FREQUÊNCIA"),
                  const SizedBox(height: 16),
                  _buildIntervalToggle(theme, colors, prefs),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildTimePicker(
                          context,
                          theme,
                          colors,
                          "Horário de Início",
                          prefs.startTimeOfDay,
                          (time) => _updatePrefs(
                            prefs.copyWith(
                              startTime: "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildTimePicker(
                          context,
                          theme,
                          colors,
                          "Horário de Término",
                          prefs.endTimeOfDay,
                          (time) => _updatePrefs(
                            prefs.copyWith(
                              endTime: "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildSectionHeader(theme, colors, "DIAS ATIVOS"),
                  const SizedBox(height: 16),
                  _buildDaysShortcuts(theme, colors, prefs),
                  const SizedBox(height: 16),
                  _buildDaysCheckboxes(theme, colors, prefs),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _updatePrefs(NotificationPreferences prefs) {
    context.read<NotificationCubit>().updatePreferences(prefs);
  }

  Widget _buildSectionHeader(ThemeData theme, ColorScheme colors, String title) {
    return Text(
      title,
      style: theme.textTheme.labelLarge?.copyWith(
        color: colors.onSurface.withValues(alpha: 0.5),
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildSwitchTile(
    ThemeData theme,
    ColorScheme colors,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildIntervalToggle(
    ThemeData theme,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    final intervals = [1, 2, 3, 4];
    return Row(
      children: intervals.map((h) {
        final isSelected = prefs.intervalHours == h;
        return Expanded(
          child: GestureDetector(
            onTap: () => _updatePrefs(prefs.copyWith(intervalHours: h)),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isSelected ? colors.primary : colors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? colors.primary : colors.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Center(
                child: Text(
                  "${h}h",
                  style: TextStyle(
                    color: isSelected ? Colors.black : colors.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTimePicker(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
    String label,
    TimeOfDay time,
    Function(TimeOfDay) onTimeSelected,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: time);
            if (picked != null) onTimeSelected(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.access_time_rounded, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDaysShortcuts(
    ThemeData theme,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildShortcutChip("Todos", [1, 2, 3, 4, 5, 6, 7], colors, prefs),
          const SizedBox(width: 8),
          _buildShortcutChip("Dias Úteis", [1, 2, 3, 4, 5], colors, prefs),
          const SizedBox(width: 8),
          _buildShortcutChip("Fins de Semana", [6, 7], colors, prefs),
        ],
      ),
    );
  }

  Widget _buildShortcutChip(
    String label,
    List<int> days,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    final isSelected = days.every((d) => prefs.activeDays.contains(d)) &&
        days.length == prefs.activeDays.length;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        if (val) _updatePrefs(prefs.copyWith(activeDays: days));
      },
    );
  }

  Widget _buildDaysCheckboxes(
    ThemeData theme,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    final dayNames = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(7, (index) {
        final dayIndex = index + 1;
        final isSelected = prefs.activeDays.contains(dayIndex);
        return FilterChip(
          label: Text(dayNames[index]),
          selected: isSelected,
          onSelected: (val) {
            final newDays = List<int>.from(prefs.activeDays);
            if (val) {
              newDays.add(dayIndex);
            } else {
              newDays.remove(dayIndex);
            }
            _updatePrefs(prefs.copyWith(activeDays: newDays));
          },
        );
      }),
    );
  }
}
