import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
// import 'package:flutter/widget_previews.dart';
// import '../../core/theme/app_theme.dart';
import './widgets/settings_view.dart';
import './widgets/add_water_button.dart';
import './widgets/history_view.dart';
import './widgets/water_lottie.dart';
import './widgets/alerts_view.dart';
import 'cubit/home_cubit.dart';
import 'cubit/home_state.dart';
import 'cubit/history_cubit.dart';
import 'cubit/settings_cubit.dart';
import 'cubit/notification_cubit.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    // HomeCubit já carrega os dados no BlocProvider inicial (main.dart).
    context.read<NotificationCubit>().loadPreferences();
    context.read<SettingsCubit>().loadSettings();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors, String name) {
    return Row(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Bem Vindo(a) ${() {
                final trimmed = name.trim();
                if (trimmed.isEmpty) return '';
                final first = trimmed.split(' ').first;
                return first[0].toUpperCase() + first.substring(1).toLowerCase();
              }()}",
              style: theme.textTheme.bodySmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text("Meu Perfil", style: theme.textTheme.titleLarge),
          ],
        ),
      ],
    );
  }

  Widget _buildCircularProgress(
    ThemeData theme,
    ColorScheme colors,
    HomeLoaded state,
  ) {
    return Center(
      child: GestureDetector(
        onTap: () => _showGoalSliderModal(context, state.dailyGoal),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background Glow
            Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.primary.withValues(alpha: 0.1),
                    blurRadius: 40,
                    spreadRadius: 10,
                  ),
                ],
              ),
            ),
            // Anel de progresso (meta de ingestão)
            SizedBox(
              width: 240,
              height: 240,
              child: CircularProgressIndicator(
                value: state.progress,
                strokeWidth: 12,
                backgroundColor: colors.primary.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(colors.primary),
                strokeCap: StrokeCap.round,
              ),
            ),
            // Inner Info
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.water_drop, color: colors.primary, size: 32),
                const SizedBox(height: 8),
                Text(
                  "${state.currentIntake}",
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontSize: 54,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  "DE ${state.dailyGoal}ml",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: colors.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        "${state.percentage}% da meta",
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.edit, color: colors.primary, size: 12),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalSliderModal(BuildContext ctx, int currentGoal) {
    final settingsCubit = ctx.read<SettingsCubit>();
    final homeCubit = ctx.read<HomeCubit>();

    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.transparent,
      builder: (_) => _GoalSliderModal(
        currentGoal: currentGoal,
        onConfirm: (newGoal) async {
          await settingsCubit.updateSetting('dailyGoal', newGoal);
          await homeCubit.refreshTodayData();
        },
      ),
    );
  }

  Widget _buildAddButton(ColorScheme colors, SettingsState settingsState) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            colors.primary.withValues(alpha: 0.8),
            colors.secondary.withValues(alpha: 0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () async {
          final error = await context.read<HomeCubit>().addWater(
            settingsState.quickAddAmount.toInt(),
          );
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        },
        icon: const Icon(Icons.add_circle, color: Colors.black),
        label: const Text(
          "Adicionar Água",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 64),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSelect(ThemeData theme, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildSelectCard(theme, colors, 200, "🥛", "Copo"),
        _buildSelectCard(theme, colors, 500, "🥤", "Garrafa"),
        _buildSelectCard(theme, colors, 1000, "🍶", "Jarra"),
      ],
    );
  }

  Widget _buildSelectCard(
    ThemeData theme,
    ColorScheme colors,
    int amount,
    String emoji,
    String label,
  ) {
    final displayAmount = amount >= 1000 ? "${amount ~/ 1000}L" : "${amount}ml";

    return Expanded(
      child: GestureDetector(
        onTap: () async {
          final error = await context.read<HomeCubit>().addWater(amount);
          if (error != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(error), backgroundColor: Colors.red),
            );
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 8),
              Text(
                displayAmount,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: colors.onSurface.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(ThemeData theme, ColorScheme colors) {
    return Text(
      "Histórico Hoje",
      style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
    );
  }

  Widget _buildHistoryItem(
    ThemeData theme,
    ColorScheme colors,
    Map<String, dynamic> log,
  ) {
    final dismissKey = GlobalObjectKey<_SwipeToDismissItemState>(log["id"]);
    return _SwipeToDismissItem(
      key: dismissKey,
      onDelete: () async {
        final int amount = log["amount"];
        await context.read<HomeCubit>().deleteWaterLog(log["id"]);

        if (context.mounted) {
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.only(bottom: 16, left: 16, right: 16),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.red,
              content: Text(
                '$amount ml excluído',
                style: const TextStyle(color: Colors.white),
              ),
              action: SnackBarAction(
                label: 'Desfazer',
                textColor: Colors.white,
                onPressed: () {
                  context.read<HomeCubit>().addWater(amount);
                },
              ),
            ),
          );
        }
      },
      child: Container(
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
                  log["id"].toString().startsWith('temp_')
                      ? "Adicionando..."
                      : log["type"],
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
              log["amount"] >= 0 ? "+${log["amount"]}ml" : "${log["amount"]}ml",
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            // Hint visual permanente: lixeira sutil à direita
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () {
                dismissKey.currentState?.slideAndDismiss();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineBanner(ColorScheme colors, HomeOffline state) {
    final isSyncing = state.isSyncing;
    final pendingCount = state.pendingCount;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.fromLTRB(24, 8, 24, 0),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isSyncing
            ? colors.primary.withValues(alpha: 0.12)
            : colors.onSurface.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSyncing
              ? colors.primary.withValues(alpha: 0.3)
              : colors.onSurface.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          if (isSyncing)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            )
          else
            Icon(
              Icons.wifi_off_rounded,
              size: 16,
              color: colors.onSurface.withValues(alpha: 0.5),
            ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isSyncing
                  ? 'Sincronizando $pendingCount registro${pendingCount > 1 ? 's' : ''} (+${state.pendingAmount}ml)...'
                  : pendingCount > 0
                  ? 'Sem conexão · $pendingCount pendente${pendingCount > 1 ? 's' : ''} (+${state.pendingAmount}ml)'
                  : 'Sem conexão · dados podem estar desatualizados',
              style: TextStyle(
                fontSize: 12,
                color: isSyncing
                    ? colors.primary
                    : colors.onSurface.withValues(alpha: 0.5),
                fontWeight: isSyncing ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineContent(
    ThemeData theme,
    ColorScheme colors,
    HomeOffline state,
  ) {
    // Cria um HomeLoaded "mocado" para reutilizar os widgets existentes
    final mockedLoaded = HomeLoaded(
      currentIntake: state.currentIntake,
      dailyGoal: state.dailyGoal,
      userName: state.userName,
      progress: state.progress,
      percentage: state.percentage,
      todayHistory: const [],
    );

    return Column(
      children: [
        _buildOfflineBanner(colors, state),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildHeader(theme, colors, state.userName),
                const SizedBox(height: 24),
                // Progresso com opacidade reduzida (dados do cache)
                Opacity(
                  opacity: 0.55,
                  child: _buildCircularProgress(theme, colors, mockedLoaded),
                ),
                const SizedBox(height: 50),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, settingsState) =>
                      _buildAddButton(colors, settingsState),
                ),
                const SizedBox(height: 24),
                _buildQuickSelect(theme, colors),
                const SizedBox(height: 40),
                // Histórico bloqueado com overlay
                Stack(
                  children: [
                    Opacity(
                      opacity: 0.3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHistoryHeader(theme, colors),
                          const SizedBox(height: 16),
                          // Items mocados como placeholder
                          for (int i = 0; i < 3; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              height: 64,
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colors.onSurface.withValues(
                                    alpha: 0.05,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Positioned.fill(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 40),
                          child: Text(
                            'Histórico disponível\nquando conectado',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: colors.onSurface.withValues(alpha: 0.4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHomeContent(ThemeData theme, ColorScheme colors) {
    return BlocConsumer<HomeCubit, HomeState>(
      listenWhen: (prev, curr) => curr is HomeLoaded && curr.syncedCount > 0,
      listener: (context, state) {
        if (state is HomeLoaded && state.syncedCount > 0) {
          final n = state.syncedCount;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 3),
              backgroundColor: Colors.green.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              content: Row(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$n registro${n > 1 ? 's' : ''} sincronizado${n > 1 ? 's' : ''} com sucesso!',
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is HomeInitial || state is HomeLoading) {
          return const Center(child: WaterLottie(size: 120));
        } else if (state is HomeOffline) {
          return _buildOfflineContent(theme, colors, state);
        } else if (state is HomeError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 60,
                  color: colors.error.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível carregar agora',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => context.read<HomeCubit>().loadTodayData(),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        } else if (state is HomeLoaded) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildHeader(theme, colors, state.userName),
                const SizedBox(height: 24),
                _buildCircularProgress(theme, colors, state),
                const SizedBox(height: 50),
                BlocBuilder<SettingsCubit, SettingsState>(
                  builder: (context, settingsState) =>
                      _buildAddButton(colors, settingsState),
                ),
                const SizedBox(height: 24),
                _buildQuickSelect(theme, colors),
                const SizedBox(height: 40),
                _buildHistoryHeader(theme, colors),
                const SizedBox(height: 16),
                if (state.todayHistory.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('Nenhum registro hoje. Respire e beba água!'),
                    ),
                  ),
                ...state.todayHistory.map(
                  (log) => _buildHistoryItem(theme, colors, log),
                ),
                const SizedBox(height: 100),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final quickAddMl = settingsState.quickAddAmount.toInt();
        return Scaffold(
          extendBody: true,
          floatingActionButton: AddWaterButton(
            milliliters: quickAddMl,
            onPressed: () async {
              final error = await context.read<HomeCubit>().addWater(
                quickAddMl,
              );
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
            onCustomAmount: (ml) async {
              final error = await context.read<HomeCubit>().addWater(ml);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(error), backgroundColor: Colors.red),
                );
              }
            },
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: BottomAppBar(
            padding: const EdgeInsets.symmetric(vertical: 8),
            height: 70,
            shape: const CircularNotchedRectangle(),
            notchMargin: 8,
            color: colors.surface,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.water_drop_rounded, "HOJE", colors),
                _buildNavItem(1, Icons.bar_chart_rounded, "HISTÓRICO", colors),
                const SizedBox(width: 48),
                _buildNavItem(
                  2,
                  Icons.notifications_rounded,
                  "ALERTAS",
                  colors,
                ),
                _buildNavItem(3, Icons.settings_rounded, "AJUSTES", colors),
              ],
            ),
          ),
          body: SafeArea(
            bottom: false,
            child: _AnimatedPageView(
              controller: _pageController,
              children: [
                _buildHomeContent(theme, colors),
                const HistoryView(),
                const AlertsView(),
                const SettingsView(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    ColorScheme colors,
  ) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () {
        if (_selectedIndex != index) {
          setState(() {
            _selectedIndex = index;
          });
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutCubic,
          );
          if (index == 0) {
            context.read<HomeCubit>().refreshTodayData();
          } else if (index == 1) {
            context.read<HistoryCubit>().loadHistory();
          }
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isSelected
                ? colors.primary
                : colors.onSurface.withValues(alpha: 0.3),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isSelected
                  ? colors.primary
                  : colors.onSurface.withValues(alpha: 0.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalSliderModal extends StatefulWidget {
  final int currentGoal;
  final void Function(int goal) onConfirm;

  const _GoalSliderModal({required this.currentGoal, required this.onConfirm});

  @override
  State<_GoalSliderModal> createState() => _GoalSliderModalState();
}

class _GoalSliderModalState extends State<_GoalSliderModal> {
  late double _goal;

  @override
  void initState() {
    super.initState();
    _goal = widget.currentGoal.toDouble().clamp(500, 5000);
  }

  String _formatGoal(double value) {
    if (value >= 1000) {
      final liters = value / 1000;
      return liters == liters.toInt()
          ? "${liters.toInt()} L"
          : "${liters.toStringAsFixed(1)} L";
    }
    return "${value.toInt()} ml";
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: colors.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "Ajustar Meta Diária",
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Quanto você quer beber por dia?",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.water_drop, color: colors.primary, size: 40),
                const SizedBox(width: 16),
                Text(
                  _formatGoal(_goal),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colors.primary,
                    fontSize: 42,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: colors.primary,
              inactiveTrackColor: colors.primary.withValues(alpha: 0.2),
              thumbColor: colors.primary,
              overlayColor: colors.primary.withValues(alpha: 0.2),
              trackHeight: 8,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
            ),
            child: Slider(
              value: _goal,
              min: 500,
              max: 5000,
              divisions: 90,
              onChanged: (value) => setState(() => _goal = value),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "500 ml",
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  "5 L",
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    side: BorderSide(color: colors.primary),
                  ),
                  child: Text(
                    "Cancelar",
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onConfirm(_goal.toInt());
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "Salvar",
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SwipeToDismissItem extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onDelete;

  const _SwipeToDismissItem({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDismissItem> createState() => _SwipeToDismissItemState();
}

class _SwipeToDismissItemState extends State<_SwipeToDismissItem>
    with SingleTickerProviderStateMixin {
  double _dragExtent = 0;
  late AnimationController _snapController;
  late Animation<double> _snapAnimation;
  double _snapStart = 0;

  // Limiar para confirmar exclusão (px)
  static const double _threshold = -72.0;
  // Máximo que o card pode ser arrastado
  static const double _maxDrag = -96.0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _snapAnimation = CurvedAnimation(
      parent: _snapController,
      curve: Curves.easeOutCubic,
    );
    _snapAnimation.addListener(() {
      setState(() {
        _dragExtent = _snapStart * (1 - _snapAnimation.value);
      });
    });
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _snapBack() {
    _snapStart = _dragExtent;
    _snapController.forward(from: 0);
  }

  Future<void> slideAndDismiss() async {
    if (_snapController.isAnimating) return;
    
    final slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    
    final slideAnim = Tween<double>(begin: _dragExtent, end: _maxDrag).animate(
      CurvedAnimation(parent: slideController, curve: Curves.easeOutCubic),
    );
    
    slideAnim.addListener(() {
      if (mounted) {
        setState(() {
          _dragExtent = slideAnim.value;
        });
      }
    });
    
    await slideController.forward();
    slideController.dispose();
    
    if (mounted) {
      await widget.onDelete();
      if (mounted) {
        setState(() => _dragExtent = 0);
      }
    }
  }

  double get _progress => (_dragExtent / _threshold).clamp(0.0, 1.0);
  bool get _pastThreshold => _dragExtent <= _threshold;

  @override
  Widget build(BuildContext context) {
    final bgOpacity = (0.08 + (_progress * 0.22)).clamp(0.0, 0.30);
    final iconScale = _pastThreshold ? 1.25 : (0.85 + _progress * 0.4);
    final iconOpacity = (0.3 + _progress * 0.7).clamp(0.0, 1.0);
    final labelOpacity = ((_progress - 0.6) / 0.4).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        if (_snapController.isAnimating) return;
        setState(() {
          _dragExtent = (_dragExtent + details.delta.dx).clamp(_maxDrag, 0.0);
        });
      },
      onHorizontalDragEnd: (details) async {
        if (_pastThreshold) {
          await widget.onDelete();
          if (mounted) {
            setState(() => _dragExtent = 0);
          }
        } else {
          _snapBack();
        }
      },
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Fundo vermelho animado
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: bgOpacity),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Transform.scale(
                    scale: iconScale,
                    child: Icon(
                      _pastThreshold
                          ? Icons.delete_rounded
                          : Icons.delete_outline_rounded,
                      color: Colors.red.withValues(alpha: iconOpacity),
                      size: 24,
                    ),
                  ),
                  if (labelOpacity > 0) ...[
                    const SizedBox(height: 4),
                    Opacity(
                      opacity: labelOpacity,
                      child: const Text(
                        'Excluir',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // Card deslizando
          Transform.translate(
            offset: Offset(_dragExtent, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class _AnimatedPageView extends StatelessWidget {
  final PageController controller;
  final List<Widget> children;

  const _AnimatedPageView({required this.controller, required this.children});

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: controller,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: children.length,
      itemBuilder: (context, index) {
        return AnimatedBuilder(
          animation: controller,
          builder: (context, child) {
            double value = 1.0;
            double slideValue = 0.0;

            if (controller.position.haveDimensions) {
              final page = controller.page ?? controller.initialPage.toDouble();
              final difference = (index - page).abs();
              value = (1 - (difference * 0.3)).clamp(0.0, 1.0);
              slideValue = (index - page) * 30;
            }

            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, slideValue.abs()),
                child: child,
              ),
            );
          },
          child: children[index],
        );
      },
    );
  }
}
