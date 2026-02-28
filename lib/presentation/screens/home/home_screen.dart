import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/ffmpeg_manager.dart';
import '../player/player_screen.dart';
import '../library/library_screen.dart';
import '../settings/settings_screen.dart';
import '../../providers/navigation_provider.dart';
import '../../providers/player_provider.dart';
import '../../widgets/app_title_bar.dart';
import '../../widgets/ffmpeg_download_dialog.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _screens = const [LibraryScreen(), PlayerScreen(), SettingsScreen()];

  late final bool _isDesktop;

  @override
  void initState() {
    super.initState();
    _isDesktop =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    if (_isDesktop) {
      HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    }
    _checkFfmpeg();
  }

  @override
  void dispose() {
    if (_isDesktop) {
      HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    }
    super.dispose();
  }

  bool _handleKeyEvent(KeyEvent event) {
    // Don't capture keys when a text field has focus
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus != null && primaryFocus.context != null) {
      // Check if the focused widget or any ancestor is an EditableText
      final editableText = primaryFocus.context!
          .findAncestorWidgetOfExactType<EditableText>();
      if (editableText != null) return false;
    }

    if (event is KeyDownEvent) {
      final notifier = ref.read(playerProvider.notifier);

      if (event.logicalKey == LogicalKeyboardKey.space) {
        notifier.togglePlayPause();
        return true;
      }
    }

    if (event is KeyDownEvent || event is KeyRepeatEvent) {
      final notifier = ref.read(playerProvider.notifier);

      if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        notifier.skipForward(const Duration(seconds: 1));
        return true;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        notifier.skipBackward(const Duration(seconds: 1));
        return true;
      }
    }

    return false;
  }

  Future<void> _checkFfmpeg() async {
    if (!FfmpegManager.isRequired) return;

    // Wait for first frame so we have a valid BuildContext for dialogs
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final manager = FfmpegManager.instance;

      // If the prompt was already shown once, try to initialize silently.
      // If initialization fails, allow re-prompt so the user can retry.
      if (await manager.isPromptShown) {
        final initialized = await manager.initialize();
        if (!initialized) {
          await manager.resetPromptShown();
        } else {
          return;
        }
      }

      // Try to find FFmpeg (might be on PATH already)
      final found = await manager.initialize();
      if (found) return;

      // FFmpeg not found — mark prompt as shown (first-run only, regardless of outcome)
      await manager.markPromptShown();

      // Show download dialog
      if (!mounted) return;
      await FfmpegDownloadDialog.show(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(navigationProvider);

    return Scaffold(
      backgroundColor: context.colors.bgDarkest,
      body: Column(
        children: [
          if (_isDesktop) const AppTitleBar(),
          Expanded(
            child: IndexedStack(index: currentIndex, children: _screens),
          ),
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
          indicatorColor: Theme.of(
            context,
          ).colorScheme.primary.withValues(alpha: 0.12),
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
              icon: Icon(
                Icons.settings_outlined,
                color: context.colors.textMuted,
              ),
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
  }
}
