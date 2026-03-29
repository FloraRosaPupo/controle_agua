import 'package:dotlottie_loader/dotlottie_loader.dart';
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
  bool _scheduledFallbackNavigation = false;

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

  void _scheduleFallbackNavigation() {
    if (_scheduledFallbackNavigation) return;
    _scheduledFallbackNavigation = true;
    Future.delayed(const Duration(seconds: 1), _navigateToNextScreen);
  }

  Widget _fallbackIcon(bool isDark) {
    _scheduleFallbackNavigation();
    return Icon(
      Icons.water_drop_rounded,
      size: 100,
      color: isDark ? Colors.white : const Color(0xFF0EA5E9),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
      body: Center(
        child: SizedBox(
          width: 200,
          height: 200,
          child: DotLottieLoader.fromAsset(
            'assets/animations/splash_water.lottie',
            frameBuilder: (context, dotLottie) {
              if (dotLottie == null) {
                return const CircularProgressIndicator(
                  color: Color(0xFF0EA5E9),
                );
              }
              final animations = dotLottie.animations;
              if (animations.isEmpty) {
                return _fallbackIcon(isDark);
              }
              final jsonBytes = animations.length == 1
                  ? animations.values.single
                  : animations.values.first;

              return Lottie.memory(
                jsonBytes,
                controller: _controller,
                onLoaded: _onAnimationLoaded,
                imageProviderFactory: dotLottie.images.isNotEmpty
                    ? (asset) {
                        final bytes = dotLottie.images[asset.fileName];
                        return bytes != null ? MemoryImage(bytes) : null;
                      }
                    : null,
                errorBuilder: (context, error, stackTrace) {
                  return _fallbackIcon(isDark);
                },
                frameBuilder: (context, child, composition) {
                  if (composition == null) {
                    return const CircularProgressIndicator(
                      color: Color(0xFF0EA5E9),
                    );
                  }
                  return child;
                },
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return _fallbackIcon(isDark);
            },
          ),
        ),
      ),
    );
  }
}
