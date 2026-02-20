import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../player/player_screen.dart';
import '../library/library_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/player_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _screens = const [
    LibraryScreen(),
    PlayerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    Widget scaffold = Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: IndexedStack(
        index: currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.bgDark,
          border: Border(
            top: BorderSide(
              color: AppColors.surfaceBorder.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) => ref.read(navigationProvider.notifier).state = i,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: 0.12),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.library_music_outlined, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.library_music_rounded, color: AppColors.primary),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.play_circle_outline_rounded, color: AppColors.textMuted),
              selectedIcon: Icon(Icons.play_circle_rounded, color: AppColors.primary),
              label: 'Player',
            ),
          ],
        ),
      ),
    );

    if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent) {
            final notifier = ref.read(playerProvider.notifier);
            if (event.logicalKey == LogicalKeyboardKey.space) {
              notifier.togglePlayPause();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              notifier.skipForward(const Duration(seconds: 5));
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              notifier.skipBackward(const Duration(seconds: 5));
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: scaffold,
      );
    }

    return scaffold;
  }
}
