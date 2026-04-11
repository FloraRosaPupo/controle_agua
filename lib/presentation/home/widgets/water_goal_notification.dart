import 'package:flutter/material.dart';

class WaterGoalNotification extends StatefulWidget {
  final int currentIntake;
  final int dailyGoal;
  final int percentage;
  final void Function(int ml)? onAddWater;

  const WaterGoalNotification({
    super.key,
    required this.currentIntake,
    required this.dailyGoal,
    required this.percentage,
    this.onAddWater,
  });

  bool get shouldShow => percentage >= 70;

  @override
  State<WaterGoalNotification> createState() => _WaterGoalNotificationState();
}

class _WaterGoalNotificationState extends State<WaterGoalNotification>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 250),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _rotationAnimation = Tween<double>(begin: 0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  String get _statusText {
    if (widget.percentage >= 100) {
      return 'Meta atingida!';
    } else if (widget.percentage >= 90) {
      return 'Quase lá!';
    } else if (widget.percentage >= 80) {
      return 'Você está indo bem!';
    } else {
      return 'Continue assim!';
    }
  }

  String get _remainingText {
    final remaining = widget.dailyGoal - widget.currentIntake;
    if (remaining <= 0) {
      return 'Parabéns! Você atingiu sua meta de ${widget.dailyGoal}ml';
    }
    return 'Faltam apenas ${remaining}ml para sua meta';
  }

  String get _motivationalText {
    if (widget.percentage >= 100) {
      return 'Excelente! Você se manteve hidratado hoje. Continue amanhã!';
    } else if (widget.percentage >= 90) {
      return 'Só mais um pouquinho! Um copo de água e você atinge sua meta!';
    } else if (widget.percentage >= 80) {
      return 'Ótimo progresso! Mantenha o ritmo para atingir sua meta.';
    } else {
      return 'Bom trabalho! Você está no caminho certo para se hidratar.';
    }
  }

  Color get _progressColor {
    if (widget.percentage >= 100) {
      return const Color(0xFF22C55E);
    } else if (widget.percentage >= 90) {
      return const Color(0xFF0EA5E9);
    } else if (widget.percentage >= 80) {
      return const Color(0xFF0EA5E9);
    } else {
      return const Color(0xFFF59E0B);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.shouldShow) return const SizedBox.shrink();

    return GestureDetector(
      onTap: _toggleExpand,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF1F2937),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header sempre visível
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _progressColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.water_drop_rounded,
                      color: _progressColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Bebeu',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '• ${widget.percentage}%',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.currentIntake}ml - ${widget.dailyGoal}ml',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: _rotationAnimation,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),

            // Barra de progresso sempre visível
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    AnimatedFractionallySizedBox(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOutCubic,
                      widthFactor: (widget.percentage / 100).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _progressColor.withValues(alpha: 0.7),
                              _progressColor,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Status sempre visível
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Icon(
                    widget.percentage >= 100
                        ? Icons.celebration_rounded
                        : Icons.local_fire_department_rounded,
                    color: _progressColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusText,
                      style: TextStyle(
                        color: _progressColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Conteúdo expansível
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: Colors.white.withValues(alpha: 0.6),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _remainingText,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _motivationalText,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botão de ação
                  if (widget.percentage < 100 && widget.onAddWater != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _QuickAddButton(
                              amount: 200,
                              emoji: '🥛',
                              onTap: () => widget.onAddWater?.call(200),
                              color: _progressColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickAddButton(
                              amount: 350,
                              emoji: '🥤',
                              onTap: () => widget.onAddWater?.call(350),
                              color: _progressColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _QuickAddButton(
                              amount: 500,
                              emoji: '🍶',
                              onTap: () => widget.onAddWater?.call(500),
                              color: _progressColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  if (widget.percentage >= 100)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _progressColor.withValues(alpha: 0.2),
                            _progressColor.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            color: _progressColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Objetivo do dia concluído!',
                            style: TextStyle(
                              color: _progressColor,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddButton extends StatelessWidget {
  final int amount;
  final String emoji;
  final VoidCallback onTap;
  final Color color;

  const _QuickAddButton({
    required this.amount,
    required this.emoji,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 4),
              Text(
                '+${amount}ml',
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnimatedWaterGoalNotification extends StatefulWidget {
  final int currentIntake;
  final int dailyGoal;
  final int percentage;
  final void Function(int ml)? onAddWater;
  final Duration animationDuration;

  const AnimatedWaterGoalNotification({
    super.key,
    required this.currentIntake,
    required this.dailyGoal,
    required this.percentage,
    this.onAddWater,
    this.animationDuration = const Duration(milliseconds: 300),
  });

  @override
  State<AnimatedWaterGoalNotification> createState() =>
      _AnimatedWaterGoalNotificationState();
}

class _AnimatedWaterGoalNotificationState
    extends State<AnimatedWaterGoalNotification> {
  bool get shouldShow => widget.percentage >= 70;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: widget.animationDuration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.3),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          ),
        );
      },
      child: shouldShow
          ? WaterGoalNotification(
              key: const ValueKey('notification'),
              currentIntake: widget.currentIntake,
              dailyGoal: widget.dailyGoal,
              percentage: widget.percentage,
              onAddWater: widget.onAddWater,
            )
          : const SizedBox.shrink(key: ValueKey('empty')),
    );
  }
}
