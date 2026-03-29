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
    // Inicia carrengando do backend!
    context.read<HomeCubit>().loadTodayData();
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
              "Bem Vindo(a) ${name.toUpperCase()}",
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
        onPressed: () => context.read<HomeCubit>().addWater(
          settingsState.quickAddAmount.toInt(),
        ),
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
        _buildSelectCard(theme, colors, 500, "🍶", "Garrafa"),
        _buildSelectCard(theme, colors, 1000, "🫗", "Jarra"),
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
        onTap: () => context.read<HomeCubit>().addWater(amount),
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
    return Dismissible(
      key: Key(log["id"].toString()),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.red),
      ),
      confirmDismiss: (direction) async {
        await context.read<HomeCubit>().deleteWaterLog(log["id"]);
        return false; // O cubit já remove da lista, não precisa do Dismissible remover
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
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(ThemeData theme, ColorScheme colors) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state is HomeInitial || state is HomeLoading) {
          return const Center(child: WaterLottie(size: 120));
        } else if (state is HomeError) {
          return Center(child: Text(state.message));
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
            onPressed: () => context.read<HomeCubit>().addWater(quickAddMl),
            onCustomAmount: (ml) => context.read<HomeCubit>().addWater(ml),
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

class _SwipeToDeleteItem extends StatefulWidget {
  final Widget child;
  final VoidCallback onDelete;

  const _SwipeToDeleteItem({
    super.key,
    required this.child,
    required this.onDelete,
  });

  @override
  State<_SwipeToDeleteItem> createState() => _SwipeToDeleteItemState();
}

class _SwipeToDeleteItemState extends State<_SwipeToDeleteItem> {
  double _dragExtent = 0;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return GestureDetector(
      onHorizontalDragUpdate: (details) {
        setState(() {
          _dragExtent += details.delta.dx;
          _dragExtent = _dragExtent.clamp(-100.0, 0.0);
        });
      },
      onHorizontalDragEnd: (details) {
        if (_dragExtent < -60) {
          widget.onDelete();
        }
        setState(() {
          _dragExtent = 0;
        });
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: Icon(
                Icons.delete_outline,
                color: Colors.red.withValues(
                  alpha: _dragExtent < -30 ? 1.0 : 0.5,
                ),
              ),
            ),
          ),
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

  const _AnimatedPageView({
    required this.controller,
    required this.children,
  });

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
