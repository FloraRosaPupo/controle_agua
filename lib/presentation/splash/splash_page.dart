import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:go_router/go_router.dart';

class SplashPage extends StatefulWidget {
  final bool isLoggedIn;

  const SplashPage({super.key, required this.isLoggedIn});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAnimationLoaded(LottieComposition composition) {
    _controller
      ..duration = composition.duration
      ..forward().whenComplete(_navigateToNextScreen);
  }

  void _navigateToNextScreen() {
    if (!mounted) return;
    
    final destination = widget.isLoggedIn ? '/home' : '/login';
    context.go(destination);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: Lottie.asset(
                'assets/animations/splash_water.lottie',
                controller: _controller,
                onLoaded: _onAnimationLoaded,
                errorBuilder: (context, error, stackTrace) {
                  Future.delayed(const Duration(seconds: 1), _navigateToNextScreen);
                  return Icon(
                    Icons.water_drop_rounded,
                    size: 100,
                    color: isDark ? Colors.white : const Color(0xFF0EA5E9),
                  );
                },
                frameBuilder: (context, child, composition) {
                  if (composition == null) {
                    return const CircularProgressIndicator(
                      color: Color(0xFF0EA5E9),
                    );
                  }
                  return child;
                },
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Bebeu',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1F2937),
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mantenha-se hidratado',
              style: TextStyle(
                fontSize: 14,
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.6) 
                    : const Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
