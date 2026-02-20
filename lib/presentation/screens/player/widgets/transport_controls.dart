import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

class TransportControls extends StatelessWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPlayPause;
  final VoidCallback? onSkipForward;
  final VoidCallback? onSkipBackward;
  final VoidCallback? onSkipToStart;
  final VoidCallback? onSkipToEnd;

  const TransportControls({
    super.key,
    required this.isPlaying,
    this.isLoading = false,
    this.onPlayPause,
    this.onSkipForward,
    this.onSkipBackward,
    this.onSkipToStart,
    this.onSkipToEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Skip to start
        _TransportButton(
          icon: Icons.skip_previous_rounded,
          onPressed: onSkipToStart,
          size: 28,
        ),

        const SizedBox(width: 8),

        // Rewind
        _TransportButton(
          icon: Icons.replay_10_rounded,
          onPressed: onSkipBackward,
          size: 30,
        ),

        const SizedBox(width: 16),

        // Play / Pause (large, glowing)
        _PlayPauseButton(
          isPlaying: isPlaying,
          isLoading: isLoading,
          onPressed: onPlayPause,
        ),

        const SizedBox(width: 16),

        // Forward
        _TransportButton(
          icon: Icons.forward_10_rounded,
          onPressed: onSkipForward,
          size: 30,
        ),

        const SizedBox(width: 8),

        // Skip to end
        _TransportButton(
          icon: Icons.skip_next_rounded,
          onPressed: onSkipToEnd,
          size: 28,
        ),
      ],
    );
  }
}

class _TransportButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;

  const _TransportButton({
    required this.icon,
    this.onPressed,
    this.size = 24,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(50),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            color: AppColors.textSecondary,
            size: size,
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatefulWidget {
  final bool isPlaying;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _PlayPauseButton({
    required this.isPlaying,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  State<_PlayPauseButton> createState() => _PlayPauseButtonState();
}

class _PlayPauseButtonState extends State<_PlayPauseButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animController.forward(),
      onTapUp: (_) {
        _animController.reverse();
        widget.onPressed?.call();
      },
      onTapCancel: () => _animController.reverse(),
      child: _ScaleAnimatedWidget(
        listenable: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.2),
                blurRadius: 40,
                spreadRadius: 5,
              ),
            ],
          ),
          child: widget.isLoading
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: AppColors.bgDarkest,
                  ),
                )
              : Icon(
                  widget.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.bgDarkest,
                  size: 36,
                ),
        ),
      ),
    );
  }
}

class _ScaleAnimatedWidget extends AnimatedWidget {
  final Widget Function(BuildContext, Widget?) builder;
  final Widget? child;

  const _ScaleAnimatedWidget({
    required super.listenable,
    required this.builder,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, child);
  }
}
