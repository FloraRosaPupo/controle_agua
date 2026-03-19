import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/widget_previews.dart';
import '../../core/theme/app_theme.dart';
import './widgets/settings_view.dart';
import './widgets/add_water_button.dart';
import 'cubit/home_cubit.dart';
import 'cubit/home_state.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    // Inicia carrengando do backend!
    context.read<HomeCubit>().loadTodayData();
  }

  Widget _buildHeader(ThemeData theme, ColorScheme colors) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [colors.primary, colors.primary.withValues(alpha: 0.3)],
            ),
          ),
          child: const CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(
              'https://i.pravatar.cc/150?u=a042581f4e29026704d',
            ), // Profile placeholder
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "BEM VINDO",
              style: theme.textTheme.bodySmall?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.bold,
                color: colors.onSurface.withValues(alpha: 0.5),
              ),
            ),
            Text("Meu Perfil", style: theme.textTheme.titleLarge),
          ],
        ),
        const Spacer(),
        Container(
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.1)),
          ),
          child: IconButton(
            icon: Icon(
              Icons.calendar_today_rounded,
              size: 20,
              color: colors.onSurface,
            ),
            onPressed: () {},
          ),
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
          // Circular Progress Indicator
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
              const SizedBox(height: 20),
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
                child: Text(
                  "${state.percentage}% DO OBJETIVO",
                  style: TextStyle(
                    color: colors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(ColorScheme colors) {
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
        onPressed: () => context.read<HomeCubit>().addWater(200),
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
        _buildSelectCard(theme, colors, "200", "ML"),
        _buildSelectCard(theme, colors, "350", "ML"),
        _buildSelectCard(theme, colors, "500", "ML"),
      ],
    );
  }

  Widget _buildSelectCard(
    ThemeData theme,
    ColorScheme colors,
    String amount,
    String unit,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: () => context.read<HomeCubit>().addWater(int.parse(amount)),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: colors.onSurface.withValues(alpha: 0.05)),
          ),
          child: Column(
            children: [
              Text(
                amount,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: colors.onSurface.withValues(alpha: 0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryHeader(ThemeData theme, ColorScheme colors) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Histórico Hoje",
          style: theme.textTheme.titleLarge?.copyWith(fontSize: 22),
        ),
        TextButton(
          onPressed: () {},
          child: Text(
            "VER TODOS",
            style: TextStyle(
              color: colors.primary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryItem(
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

  Widget _buildHomeContent(ThemeData theme, ColorScheme colors) {
    return BlocBuilder<HomeCubit, HomeState>(
      builder: (context, state) {
        if (state is HomeInitial || state is HomeLoading) {
          return const Center(child: CircularProgressIndicator());
        } else if (state is HomeError) {
          return Center(child: Text(state.message));
        } else if (state is HomeLoaded) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                _buildHeader(theme, colors),
                const SizedBox(height: 24),
                _buildCircularProgress(theme, colors, state),
                const SizedBox(height: 50),
                _buildAddButton(colors),
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

    return Scaffold(
      extendBody: true,
      floatingActionButton: AddWaterButton(
        onPressed: () => context.read<HomeCubit>().addWater(50),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
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
            _buildNavItem(2, Icons.notifications_rounded, "ALERTAS", colors),
            _buildNavItem(3, Icons.settings_rounded, "AJUSTES", colors),
          ],
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomeContent(theme, colors),
            const Center(child: Text("Histórico")), // Placeholder
            const Center(child: Text("Alertas")), // Placeholder
            const SettingsView(),
          ],
        ),
      ),
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
      onTap: () => setState(() => _selectedIndex = index),
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
