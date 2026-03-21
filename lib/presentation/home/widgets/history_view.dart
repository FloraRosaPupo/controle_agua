import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        if (state is HistoryInitial || state is HistoryLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is HistoryError) {
          return Center(child: Text(state.message));
        }

        if (state is HistoryLoaded) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, theme, colors, state),
                const SizedBox(height: 24),
                _buildStats(theme, colors, state),
                const SizedBox(height: 32),
                _buildChartSection(theme, colors, state),
                const SizedBox(height: 32),
                _buildDailyLogs(theme, colors, state),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, ColorScheme colors, HistoryLoaded state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Progresso Semanal",
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Text(
                state.selectedPeriod == '7d' ? "ÚLTIMOS 7 DIAS" : "ÚLTIMOS 30 DIAS",
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              const Icon(Icons.keyboard_arrow_down, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStats(ThemeData theme, ColorScheme colors, HistoryLoaded state) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            colors,
            "MÉDIA DIÁRIA",
            "${state.stats['average']}",
            "ml",
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme,
            colors,
            "META BATIDA",
            "${state.stats['goalsMet']}/${state.stats['totalDays']}",
            "dias",
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(ThemeData theme, ColorScheme colors, String label, String value, String unit) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900, color: colors.onSurface),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(color: colors.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(ThemeData theme, ColorScheme colors, HistoryLoaded state) {
    // Agrupar logs por dia para o gráfico
    final Map<String, int> dailySums = {};
    final now = DateTime.now();
    for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final key = DateFormat('yyyy-MM-dd').format(date);
        dailySums[key] = 0;
    }

    for (var log in state.logs) {
        final dateStr = (log['date'] as String).split('T')[0];
        if (dailySums.containsKey(dateStr)) {
            dailySums[dateStr] = (dailySums[dateStr] ?? 0) + (log['amount'] as int);
        }
    }

    final List<String> weekDays = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           mainAxisAlignment: MainAxisAlignment.spaceBetween,
           children: [
              Text("Volume de Hidratação", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text("Meta: ${state.dailyGoal}ml", style: TextStyle(color: colors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
           ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailySums.entries.map((entry) {
              final double progress = (entry.value / state.dailyGoal).clamp(0.0, 1.2);
              final dayIndex = DateTime.parse(entry.key).weekday - 1;
              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(
                    width: 30,
                    height: 140 * progress,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: progress >= 1.0 
                          ? [colors.primary, colors.primary.withValues(alpha: 0.6)]
                          : [colors.onSurface.withValues(alpha: 0.1), colors.onSurface.withValues(alpha: 0.2)],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: progress >= 1.0 ? [
                        BoxShadow(color: colors.primary.withValues(alpha: 0.3), blurRadius: 8, spreadRadius: 1)
                      ] : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    weekDays[dayIndex % 7],
                    style: TextStyle(fontSize: 10, color: colors.onSurface.withValues(alpha: 0.4), fontWeight: FontWeight.bold),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLogs(ThemeData theme, ColorScheme colors, HistoryLoaded state) {
    // Agrupar logs por dia para a lista "REGISTROS DIÁRIOS"
    final Map<String, int> dailyTotals = {};
    for (var log in state.logs) {
      final dateStr = (log['date'] as String).split('T')[0];
      dailyTotals[dateStr] = (dailyTotals[dateStr] ?? 0) + (log['amount'] as int);
    }

    final sortedDays = dailyTotals.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.history, size: 16, color: colors.primary),
            const SizedBox(width: 8),
            Text(
              "REGISTROS DIÁRIOS",
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...sortedDays.take(7).map((day) {
          final amount = dailyTotals[day]!;
          final date = DateTime.parse(day);
          final percent = ((amount / state.dailyGoal) * 100).toInt();
          final isMet = amount >= state.dailyGoal;
          
          return _buildHistoryItem(
            theme, 
            colors, 
            {
              "type": "${_getShortDayName(date)} ${date.day}",
              "time": "${percent}% da meta",
              "amount": _formatAmount(amount).replaceAll('ml', ''),
              "isMet": isMet,
            }
          );
        }),
      ],
    );
  }

  Widget _buildHistoryItem(
    ThemeData theme,
    ColorScheme colors,
    Map<String, dynamic> log,
  ) {
    final bool isMet = log["isMet"] ?? false;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.local_drink_outlined,
              color: colors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log["type"],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                log["time"],
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                "${log["amount"]}ml",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              if (isMet) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle, color: colors.primary, size: 20),
              ]
            ],
          ),
        ],
      ),
    );
  }

  String _getShortDayName(DateTime date) {
    const names = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"];
    return names[date.weekday - 1];
  }

  String _formatAmount(int amount) {
    return NumberFormat("#,###", "pt_BR").format(amount).replaceAll(',', '.');
  }
}
