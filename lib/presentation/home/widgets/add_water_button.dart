import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';
import 'package:bebeu/core/theme/app_theme.dart';

class AddWaterButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const AddWaterButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
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
        onPressed: onPressed ?? () {},
        backgroundColor: colors.primary,
        elevation: 0,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.black, size: 32),
      ),
    );
  }
}

@Preview(name: 'Add Water Button - Light')
Widget addWaterButtonLightPreview() {
  return MaterialApp(
    theme: AppTheme.lightTheme,
    debugShowCheckedModeBanner: false,
    home: const AddWaterButton(),
  );
}

@Preview(name: 'Add Water Button - Dark')
Widget addWaterButtonDarkPreview() {
  return MaterialApp(
    theme: AppTheme.darkTheme,
    debugShowCheckedModeBanner: false,
    home: const AddWaterButton(),
  );
}
