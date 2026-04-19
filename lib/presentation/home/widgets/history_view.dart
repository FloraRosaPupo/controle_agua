import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'water_lottie.dart';
import '../cubit/history_cubit.dart';
import '../cubit/history_state.dart';
import '../cubit/home_cubit.dart';

class HistoryView extends StatelessWidget {
  const HistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocBuilder<HistoryCubit, HistoryState>(
      builder: (context, state) {
        if (state is HistoryInitial || state is HistoryLoading) {
          return const Center(child: WaterLottie(size: 120));
        }

        if (state is HistoryError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 60,
                  color: colors.error.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Sem conexão ou erro de rede',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'Verifique sua conexão com a internet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.read<HistoryCubit>().loadHistory(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
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
                _buildDailyLogs(context, theme, colors, state),
                const SizedBox(height: 100),
              ],
            ),
          );
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
    HistoryLoaded state,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Progresso Semanal",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        _buildWeekRange(theme, colors),
      ],
    );
  }

  Widget _buildStats(ThemeData theme, ColorScheme colors, HistoryLoaded state) {
    // Calcular estatísticas com base nos dias visíveis no gráfico (semana atual)
    final Map<String, int> dailySums = {};
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));

    for (int i = 0; i < 7; i++) {
      final date = sunday.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      dailySums[key] = 0;
    }

    for (var log in state.logs) {
      final localDate = DateTime.parse(log['date'].toString()).toLocal();
      final dateStr = DateFormat('yyyy-MM-dd').format(localDate);
      if (dailySums.containsKey(dateStr)) {
        dailySums[dateStr] = (dailySums[dateStr] ?? 0) + (log['amount'] as int);
      }
    }

    int totalIntake = 0;
    int goalsMet = 0;

    dailySums.forEach((dateStr, amount) {
      totalIntake += amount;
      if (amount >= state.dailyGoal) {
        goalsMet++;
      }
    });

    int daysElapsed = (now.weekday % 7) + 1; // Dom = 1, Seg = 2, ..., Sab = 7
    int average = daysElapsed > 0 ? (totalIntake / daysElapsed).round() : 0;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            theme,
            colors,
            "MÉDIA DIÁRIA",
            "$average",
            "ml",
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            theme,
            colors,
            "META BATIDA",
            "$goalsMet/7",
            "dias",
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    ThemeData theme,
    ColorScheme colors,
    String label,
    String value,
    String unit,
  ) {
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
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurface.withValues(alpha: 0.4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(
    ThemeData theme,
    ColorScheme colors,
    HistoryLoaded state,
  ) {
    return _ChartSection(theme: theme, colors: colors, state: state);
  }

  Widget _buildDailyLogsHeader(
    ThemeData theme,
    ColorScheme colors,
    HistoryLoaded state,
  ) {
    return Row(
      children: [
        Icon(Icons.history_rounded, color: colors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          "ÚLTIMOS ${state.selectedPeriod.replaceAll('d', '').toUpperCase()} DIAS",
          style: theme.textTheme.labelLarge?.copyWith(
            color: colors.primary,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildDailyLogs(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
    HistoryLoaded state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildDailyLogsHeader(theme, colors, state),
            IconButton(
              onPressed: () => _showManualAddModal(context, state),
              icon: const Icon(Icons.add_rounded),
              style: ElevatedButton.styleFrom(
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                foregroundColor: colors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (state.logs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "Nenhum registro encontrado nos últimos ${state.selectedPeriod.replaceAll('d', '')} dias.",
              ),
            ),
          ),
        ...state.logs.map((log) {
          final date = DateTime.parse(log['date'].toString()).toLocal();
          return _buildHistoryItem(context, theme, colors, {
            "id": log['id'],
            "type": "Água",
            "time":
                "${_getShortDayName(date)} ${date.day} - ${DateFormat('HH:mm').format(date)}",
            "amount": log['amount'],
          });
        }),
      ],
    );
  }

  Widget _buildHistoryItem(
    BuildContext context,
    ThemeData theme,
    ColorScheme colors,
    Map<String, dynamic> log,
  ) {
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
          Text(
            "+${log["amount"]}ml",
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _getShortDayName(DateTime date) {
    const names = ["SEG", "TER", "QUA", "QUI", "SEX", "SÁB", "DOM"];
    return names[date.weekday - 1];
  }

  Widget _buildWeekRange(ThemeData theme, ColorScheme colors) {
    final now = DateTime.now();
    // Calcula domingo anterior (ou hoje se for domingo)
    final sunday = now.subtract(Duration(days: now.weekday % 7));
    final saturday = sunday.add(const Duration(days: 6));

    final startStr =
        "${_getShortDayName(sunday)} ${sunday.day.toString().padLeft(2, '0')}/${sunday.month.toString().padLeft(2, '0')}";
    final endStr =
        "${_getShortDayName(saturday)} ${saturday.day.toString().padLeft(2, '0')}/${saturday.month.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        "$startStr - $endStr",
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.onSurface.withValues(alpha: 0.6),
          fontWeight: FontWeight.bold,
          fontSize: 10,
        ),
      ),
    );
  }

  void _showManualAddModal(BuildContext context, HistoryLoaded state) {
    showDialog(
      context: context,
      builder: (dialogContext) => _ManualAddDialog(
        onConfirm: (amount, date) async {
          // Feedback visual imediato
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Adicionando ${amount}ml..."),
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );

          await context.read<HistoryCubit>().addWaterManual(amount, date);

          final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
          final selectedDate = DateFormat('yyyy-MM-dd').format(date);
          if (today == selectedDate && context.mounted) {
            context.read<HomeCubit>().refreshTodayData();
          }
        },
      ),
    );
  }
}

class _ChartSection extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme colors;
  final HistoryLoaded state;

  const _ChartSection({
    required this.theme,
    required this.colors,
    required this.state,
  });

  @override
  State<_ChartSection> createState() => _ChartSectionState();
}

class _ChartSectionState extends State<_ChartSection> {
  String? selectedDayKey;

  @override
  Widget build(BuildContext context) {
    // Agrupar logs por dia para o gráfico (semana atual)
    final Map<String, int> dailySums = {};
    final now = DateTime.now();
    final sunday = now.subtract(Duration(days: now.weekday % 7));

    for (int i = 0; i < 7; i++) {
      final date = sunday.add(Duration(days: i));
      final key = DateFormat('yyyy-MM-dd').format(date);
      dailySums[key] = 0;
    }

    for (var log in widget.state.logs) {
      final localDate = DateTime.parse(log['date'].toString()).toLocal();
      final dateStr = DateFormat('yyyy-MM-dd').format(localDate);
      if (dailySums.containsKey(dateStr)) {
        dailySums[dateStr] = (dailySums[dateStr] ?? 0) + (log['amount'] as int);
      }
    }

    final List<String> weekDays = [
      "SEG",
      "TER",
      "QUA",
      "QUI",
      "SEX",
      "SÁB",
      "DOM",
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Volume de Hidratação",
              style: widget.theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              "Meta: ${widget.state.dailyGoal}ml",
              style: TextStyle(
                color: widget.colors.primary,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 220,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: dailySums.entries.map((entry) {
              final double progress = (entry.value / widget.state.dailyGoal)
                  .clamp(0.0, 1.2);
              final dayIndex = DateTime.parse(entry.key).weekday - 1;
              final bool isSelected = selectedDayKey == entry.key;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      selectedDayKey = null;
                    } else {
                      selectedDayKey = entry.key;
                    }
                  });
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isSelected)
                      Container(
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: widget.colors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "${entry.value}ml",
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: widget.colors.onPrimary,
                          ),
                        ),
                      ),
                    Container(
                      width: 30,
                      height: 140 * progress,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: progress >= 1.0
                              ? [
                                  widget.colors.primary,
                                  widget.colors.primary.withValues(alpha: 0.6),
                                ]
                              : [
                                  widget.colors.onSurface.withValues(
                                    alpha: 0.1,
                                  ),
                                  widget.colors.onSurface.withValues(
                                    alpha: 0.2,
                                  ),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: progress >= 1.0
                            ? [
                                BoxShadow(
                                  color: widget.colors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      weekDays[dayIndex % 7],
                      style: TextStyle(
                        fontSize: 10,
                        color: isSelected
                            ? widget.colors.primary
                            : widget.colors.onSurface.withValues(alpha: 0.4),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _ManualAddDialog extends StatefulWidget {
  final Function(int amount, DateTime date) onConfirm;

  const _ManualAddDialog({required this.onConfirm});

  @override
  State<_ManualAddDialog> createState() => _ManualAddDialogState();
}

class _ManualAddDialogState extends State<_ManualAddDialog> {
  late DateTime selectedDate;
  final TextEditingController _amountController = TextEditingController(
    text: '200',
  );

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: colors.surface,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Adicionar Registro",
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "DATA",
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () => _selectDate(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colors.onSurface.withValues(alpha: 0.1),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 18,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      DateFormat('dd/MM/yyyy').format(selectedDate),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              "QUANTIDADE (ML)",
              style: theme.textTheme.labelSmall?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.primary,
              ),
              decoration: InputDecoration(
                suffixText: "ml",
                hintText: "0",
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colors.onSurface.withValues(alpha: 0.1),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colors.onSurface.withValues(alpha: 0.1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text("Cancelar"),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = int.tryParse(_amountController.text) ?? 0;
                      if (amount > 0) {
                        widget.onConfirm(amount, selectedDate);
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.primary,
                      foregroundColor: colors.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      "Confirmar",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
