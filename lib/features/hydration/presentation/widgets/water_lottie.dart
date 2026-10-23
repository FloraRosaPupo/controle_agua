import 'package:dotlottie_loader/dotlottie_loader.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Caminho do asset compartilhado com o splash (formato dotLottie).
const String kWaterLottieAsset = 'assets/animations/splash_water.lottie';

/// Lottie de água em loop — loading ou decoração (ex.: círculo da meta).
class WaterLottie extends StatelessWidget {
  const WaterLottie({super.key, required this.size, this.clipCircular = false});

  final double size;
  final bool clipCircular;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    Widget core = DotLottieLoader.fromAsset(
      kWaterLottieAsset,
      frameBuilder: (context, dotLottie) {
        if (dotLottie == null) {
          return Center(
            child: Icon(
              Icons.water_drop,
              size: size * 0.35,
              color: colors.primary.withValues(alpha: 0.35),
            ),
          );
        }
        final animations = dotLottie.animations;
        if (animations.isEmpty) {
          return Center(
            child: Icon(
              Icons.water_drop,
              size: size * 0.45,
              color: colors.primary,
            ),
          );
        }
        final jsonBytes = animations.length == 1
            ? animations.values.single
            : animations.values.first;

        return Lottie.memory(
          jsonBytes,
          repeat: true,
          fit: BoxFit.contain,
          imageProviderFactory: dotLottie.images.isNotEmpty
              ? (asset) {
                  final bytes = dotLottie.images[asset.fileName];
                  return bytes != null ? MemoryImage(bytes) : null;
                }
              : null,
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: Icon(
            Icons.water_drop,
            size: size * 0.45,
            color: colors.primary,
          ),
        );
      },
    );

    core = SizedBox(width: size, height: size, child: core);
    if (clipCircular) {
      core = ClipOval(child: core);
    }
    return core;
  }
}
