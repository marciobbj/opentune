import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../player/player_screen.dart';
import '../library/library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _screens = const [
    LibraryScreen(),
    PlayerScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDarkest,
      body: IndexedStack(
        index: _currentIndex,
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
          selectedIndex: _currentIndex,
          onDestinationSelected: (i) => setState(() => _currentIndex = i),
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
  }
}
