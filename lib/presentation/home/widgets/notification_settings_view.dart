import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/notification_cubit.dart';
import '../../../../core/models/notification_preferences.dart';

class NotificationSettingsView extends StatefulWidget {
  const NotificationSettingsView({super.key});

  @override
  State<NotificationSettingsView> createState() =>
      _NotificationSettingsViewState();
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
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: Text(
          "Configurações de Alerta",
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: colors.primary,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
            onPressed: () {},
          ),
        ],
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Ativar Notificações ---
                  _buildMainCard(
                    colors: colors,
                    child: SwitchListTile(
                      title: Text(
                        "Ativar Notificações",
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "Receber lembretes de hidratação",
                        style: textTheme.bodySmall,
                      ),
                      value: prefs.enabled,
                      onChanged: (val) =>
                          _updatePrefs(prefs.copyWith(enabled: val)),
                      activeThumbColor: colors.primary,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Frequência ---
                  _buildMainCard(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          textTheme,
                          colors,
                          Icons.timer_outlined,
                          "FREQUÊNCIA",
                        ),
                        const SizedBox(height: 16),
                        _buildIntervalToggle(theme, colors, prefs),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Intervalo de Tempo ---
                  _buildMainCard(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          textTheme,
                          colors,
                          Icons.access_time,
                          "INTERVALO DE TEMPO",
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _buildTimePicker(
                                context,
                                theme,
                                colors,
                                "Início",
                                prefs.startTimeOfDay,
                                (time) => _updatePrefs(
                                  prefs.copyWith(
                                    startTime:
                                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildTimePicker(
                                context,
                                theme,
                                colors,
                                "Término",
                                prefs.endTimeOfDay,
                                (time) => _updatePrefs(
                                  prefs.copyWith(
                                    endTime:
                                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Dias Ativos ---
                  _buildMainCard(
                    colors: colors,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionLabel(
                          textTheme,
                          colors,
                          Icons.calendar_today_outlined,
                          "DIAS ATIVOS",
                        ),
                        const SizedBox(height: 16),
                        _buildDaysShortcuts(theme, colors, prefs),
                        const SizedBox(height: 24),
                        _buildDaysRow(theme, colors, prefs),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // --- Dica de Saúde ---
                  _buildHealthTipCard(theme, colors),
                  const SizedBox(height: 20),
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

  Widget _buildMainCard({required ColorScheme colors, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surface, // Usando a cor de superfície do tema (AppColors.cardDark no modo escuro)
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }

  Widget _buildSectionLabel(
      TextTheme textTheme, ColorScheme colors, IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(
            color: colors.onSurface.withValues(alpha: 0.5),
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildIntervalToggle(
    ThemeData theme,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    final intervals = [1, 2, 3, 4];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: intervals.map((h) {
        final isSelected = prefs.intervalHours == h;
        return GestureDetector(
          onTap: () => _updatePrefs(prefs.copyWith(intervalHours: h)),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected
                  ? Colors.transparent
                  : colors.onSurface.withValues(alpha: 0.05),
              border: Border.all(
                color: isSelected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.1),
                width: 2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: colors.primary.withValues(alpha: 0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                "${h}h",
                style: TextStyle(
                  color: isSelected
                      ? colors.primary
                      : colors.onSurface.withValues(alpha: 0.5),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
    final textTheme = theme.textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colors.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              builder: (context, child) {
                return Theme(
                  data: theme.copyWith(
                    colorScheme: colors.copyWith(
                      surface: colors.surface,
                      onSurface: colors.onSurface,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (picked != null) onTimeSelected(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
                  style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Icon(
                  Icons.access_time_filled,
                  size: 18,
                  color: colors.onSurface.withValues(alpha: 0.3),
                ),
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildShortcutChip("Todos", [1, 2, 3, 4, 5, 6, 7], colors, prefs),
        _buildShortcutChip("Dias Úteis", [1, 2, 3, 4, 5], colors, prefs),
        _buildShortcutChip("Fins de Semana", [6, 7], colors, prefs),
      ],
    );
  }

  Widget _buildShortcutChip(
    String label,
    List<int> days,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    final isSelected =
        days.every((d) => prefs.activeDays.contains(d)) &&
        days.length == prefs.activeDays.length;
    return GestureDetector(
      onTap: () => _updatePrefs(prefs.copyWith(activeDays: days)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colors.primary
              : colors.onSurface.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.black
                : colors.onSurface.withValues(alpha: 0.6),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildDaysRow(
    ThemeData theme,
    ColorScheme colors,
    NotificationPreferences prefs,
  ) {
    final dayNames = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(7, (index) {
        final dayIndex = index + 1;
        final isSelected = prefs.activeDays.contains(dayIndex);
        return Column(
          children: [
            GestureDetector(
              onTap: () {
                final newDays = List<int>.from(prefs.activeDays);
                if (isSelected) {
                  newDays.remove(dayIndex);
                } else {
                  newDays.add(dayIndex);
                }
                _updatePrefs(prefs.copyWith(activeDays: newDays));
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Colors.transparent
                      : colors.onSurface.withValues(alpha: 0.02),
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                child: isSelected
                    ? Icon(Icons.check, color: colors.primary, size: 18)
                    : null,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              dayNames[index],
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.4),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildHealthTipCard(ThemeData theme, ColorScheme colors) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.1), // Usando cor principal do tema para a dica
        borderRadius: BorderRadius.circular(24),
        image: const DecorationImage(
          image: AssetImage(
            'assets/images/logo.png',
          ), // Using logo as a subtle watermark/bg
          alignment: Alignment.centerRight,
          opacity: 0.05,
          scale: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 30, height: 1, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                "DICA DE SAÚDE",
                style: TextStyle(
                  color: colors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Manter-se hidratado ajuda a manter o foco e a energia durante o dia todo.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
