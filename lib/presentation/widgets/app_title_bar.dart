import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../core/theme/app_colors.dart';

/// Custom title bar for all desktop platforms.
/// - macOS: shows drag area + title only (traffic lights are native)
/// - Windows/Linux: shows drag area + title + custom window control buttons
class AppTitleBar extends StatelessWidget {
  const AppTitleBar({super.key});

  static bool get _isMacOS => !kIsWeb && Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => windowManager.startDragging(),
      child: Container(
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
        child: Stack(
          children: [
            // Centered title
            Center(
              child: Text(
                'OpenTune',
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            // Window control buttons on the right (Windows/Linux only)
            if (!_isMacOS)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _WindowButton(
                      icon: Icons.remove_rounded,
                      onPressed: () => windowManager.minimize(),
                      hoverColor: context.colors.surfaceLight,
                    ),
                    _WindowButton(
                      icon: Icons.crop_square_rounded,
                      onPressed: () async {
                        final isMaximized = await windowManager.isMaximized();
                        if (isMaximized) {
                          await windowManager.unmaximize();
                        } else {
                          await windowManager.maximize();
                        }
                      },
                      hoverColor: context.colors.surfaceLight,
                    ),
                    _WindowButton(
                      icon: Icons.close_rounded,
                      onPressed: () => windowManager.close(),
                      hoverColor: const Color(0xFFE81123),
                      hoverIconColor: Colors.white,
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

class _WindowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowButton({
    required this.icon,
    required this.onPressed,
    required this.hoverColor,
    this.hoverIconColor,
  });

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46,
          height: 36,
          color: _isHovered ? widget.hoverColor : Colors.transparent,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: 16,
            color: _isHovered && widget.hoverIconColor != null
                ? widget.hoverIconColor
                : context.colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
