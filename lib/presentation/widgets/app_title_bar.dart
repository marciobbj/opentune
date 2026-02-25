import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: context.colors.bgDarkest,
        border: Border(
          bottom: BorderSide(
            color: context.colors.surfaceBorder.withValues(alpha: 0.2),
            width: 0.5,
          ),
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        'OpenTune',
        style: TextStyle(
          color: context.colors.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
