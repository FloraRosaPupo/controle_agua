import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:bebeu/core/theme/app_theme.dart';

class AddWaterButton extends StatefulWidget {
  final VoidCallback? onPressed;

  /// Volume exibido no feedback visual (ex.: "+ 50 ml").
  final int milliliters;

  const AddWaterButton({
    super.key,
    this.onPressed,
    this.milliliters = 50,
  });

  @override
  State<AddWaterButton> createState() => _AddWaterButtonState();
}

class _AddWaterButtonState extends State<AddWaterButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  bool _showBurst = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _opacity = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.28, 1, curve: Curves.easeOut),
      ),
    );
    _slide = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0, -2.2),
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() {
          _showBurst = false;
        });
        _controller.reset();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() => _showBurst = true);
    _controller.forward(from: 0);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        if (_showBurst)
          Positioned(
            bottom: 64,
            child: IgnorePointer(
              child: FadeTransition(
                opacity: _opacity,
                child: SlideTransition(
                  position: _slide,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceContainerHighest.withValues(
                        alpha: 0.92,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: colors.shadow.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      '+ ${widget.milliliters} ml',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: colors.primary,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: colors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton(
            onPressed: _handleTap,
            backgroundColor: colors.primary,
            elevation: 0,
            shape: const CircleBorder(),
            child: const Icon(Icons.add, color: Colors.black, size: 32),
          ),
        ),
      ],
    );
  }
}

@Preview(name: 'Add Water Button - Light')
Widget addWaterButtonLightPreview() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: const Scaffold(
      body: Center(child: AddWaterButton()),
    ),
  );
}

@Preview(name: 'Add Water Button - Dark')
Widget addWaterButtonDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: const Scaffold(
      body: Center(child: AddWaterButton()),
    ),
  );
}
