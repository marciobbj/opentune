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

/// A [SingleActivator] that only accepts when no [EditableText] has focus.
/// This prevents player shortcuts (space, arrows) from firing while the user
/// is typing in a text field.
class _PlayerKeyActivator extends SingleActivator {
  const _PlayerKeyActivator(super.trigger, {super.includeRepeats});

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (!super.accepts(event, state)) return false;
    final pf = FocusManager.instance.primaryFocus;
    if (pf?.context != null) {
      if (pf!.context!.findAncestorWidgetOfExactType<EditableText>() !=
          null) {
        return false;
      }
    }
    return true;
  }
}

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _screens = const [LibraryScreen(), PlayerScreen(), SettingsScreen()];

  late final bool _isDesktop;
  DateTime? _lastSpacePress;
  static const int _doubleSpaceThresholdMs = 400;

  @override
  void initState() {
    super.initState();
    _isDesktop =
        !kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS);
    _checkFfmpeg();
  }

  void _handleSpace() {
    final notifier = ref.read(playerProvider.notifier);
    final now = DateTime.now();
    if (_lastSpacePress != null &&
        now.difference(_lastSpacePress!).inMilliseconds <
            _doubleSpaceThresholdMs) {
      _lastSpacePress = null;
      notifier.seekToLoopSectionStart();
    } else {
      _lastSpacePress = now;
      notifier.togglePlayPause();
    }
  }

  void _handleSkipForward() {
    ref.read(playerProvider.notifier).skipForward(const Duration(seconds: 1));
  }

  void _handleSkipBackward() {
    ref.read(playerProvider.notifier).skipBackward(const Duration(seconds: 1));
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

    Widget content = Scaffold(
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

    // On desktop, intercept Space and Arrow keys within the focus tree.
    // This is critical because HardwareKeyboard.addHandler returning true
    // does NOT prevent Flutter's focus-tree key handling from also processing
    // the same event. Without this, arrow keys trigger DirectionalFocusIntent
    // (moving focus onto NavigationBar buttons) and Space triggers
    // ActivateIntent (activating the focused button and switching tabs).
    //
    // CallbackShortcuts operates inside the focus tree, so returning "handled"
    // properly blocks ActivateIntent and DirectionalFocusIntent from firing.
    if (_isDesktop) {
      content = CallbackShortcuts(
        bindings: <ShortcutActivator, VoidCallback>{
          const _PlayerKeyActivator(
            LogicalKeyboardKey.space,
            includeRepeats: false,
          ): _handleSpace,
          const _PlayerKeyActivator(LogicalKeyboardKey.arrowRight):
              _handleSkipForward,
          const _PlayerKeyActivator(LogicalKeyboardKey.arrowLeft):
              _handleSkipBackward,
        },
        child: Focus(autofocus: true, child: content),
      );
    }

    return content;
  }
}
