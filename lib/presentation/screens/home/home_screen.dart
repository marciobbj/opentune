import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../player/player_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/app_title_bar.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _screens = const [LibraryScreen(), PlayerScreen(), SettingsScreen()];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    final bool isDesktop = !kIsWeb &&
        (Platform.isLinux || Platform.isWindows || Platform.isMacOS);

    Widget scaffold = Scaffold(
      backgroundColor: context.colors.bgDarkest,
      body: Column(
        children: [
          if (isDesktop) const AppTitleBar(),
          Expanded(child: IndexedStack(index: currentIndex, children: _screens)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.colors.bgDark,
          border: Border(
            top: BorderSide(
              color: context.colors.surfaceBorder.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: currentIndex,
          onDestinationSelected: (i) =>
              ref.read(navigationProvider.notifier).state = i,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          height: 68,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: [
            NavigationDestination(
              icon: Icon(
                Icons.library_music_outlined,
                color: context.colors.textMuted,
              ),
              selectedIcon: Icon(
                Icons.library_music_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(
                Icons.play_circle_outline_rounded,
                color: context.colors.textMuted,
              ),
              selectedIcon: Icon(
                Icons.play_circle_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Player',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined, color: context.colors.textMuted),
              selectedIcon: Icon(
                Icons.settings_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );

    if (isDesktop) {
      return Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent || event is KeyRepeatEvent) {
            final notifier = ref.read(playerProvider.notifier);

            if (event.logicalKey == LogicalKeyboardKey.space &&
                event is KeyDownEvent) {
              notifier.togglePlayPause();
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
              notifier.skipForward(const Duration(seconds: 1));
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
              notifier.skipBackward(const Duration(seconds: 1));
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
