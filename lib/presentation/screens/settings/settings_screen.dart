import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/cache_service.dart';
import '../../providers/settings_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  int _cacheSizeBytes = 0;
  bool _isCacheLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    final size = await CacheService.getCacheSize();
    if (mounted) setState(() => _cacheSizeBytes = size);
  }

  Future<void> _clearCache() async {
    // Capture context-dependent objects before any async gap.
    final messenger = ScaffoldMessenger.of(context);
    final colors = context.colors;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: colors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear Cache', style: TextStyle(color: colors.textPrimary)),
        content: Text(
          'This will remove waveform cache files '
          '(${CacheService.formatSize(_cacheSizeBytes)}) and flush the '
          'in-memory image cache. Waveforms will be re-generated the next '
          'time you play a track.',
          style: TextStyle(color: colors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Clear',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCacheLoading = true);
    final freed = await CacheService.clearAll();
    await _loadCacheSize();
    if (mounted) {
      setState(() => _isCacheLoading = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            freed > 0
                ? 'Cache cleared — ${CacheService.formatSize(freed)} freed.'
                : 'Cache was already empty.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final customColor = ref.watch(
      settingsProvider.select((s) => s.customPrimaryColor),
    );
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));
    final currentColor = customColor ?? context.colors.primary;

    final showAlbumArt = ref.watch(
      settingsProvider.select((s) => s.showAlbumArtInPlayer),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Appearance',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : themeMode == ThemeMode.light
                          ? Icons.light_mode_rounded
                          : Icons.brightness_auto_rounded,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    title: const Text(
                      'Theme',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Choose light, dark, or system default',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: DropdownButton<ThemeMode>(
                      value: themeMode,
                      dropdownColor: Theme.of(context).cardTheme.color,
                      underline: const SizedBox(),
                      icon: Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Theme.of(context).iconTheme.color,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ThemeMode.system,
                          child: Text('System'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.light,
                          child: Text('Light'),
                        ),
                        DropdownMenuItem(
                          value: ThemeMode.dark,
                          child: Text('Dark'),
                        ),
                      ],
                      onChanged: (mode) {
                        if (mode != null) {
                          ref
                              .read(settingsProvider.notifier)
                              .setThemeMode(mode);
                        }
                      },
                    ),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: currentColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          width: 2,
                        ),
                      ),
                    ),
                    title: const Text(
                      'Primary Color',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Choose the main accent color',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    onTap: () => _showColorPickerDialog(context, currentColor),
                  ),
                  Divider(
                    height: 1,
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                  ),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Icon(
                      Icons.refresh_rounded,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    title: const Text('Reset to Default Color'),
                    onTap: () {
                      ref.read(settingsProvider.notifier).resetPrimaryColor();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Color reset to default!'),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Player',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  width: 0.5,
                ),
              ),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                secondary: Icon(
                  Icons.album_rounded,
                  color: Theme.of(context).iconTheme.color,
                ),
                title: const Text(
                  'Album Art in Player',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  'Show the album cover behind the waveform',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: showAlbumArt,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (value) {
                  ref
                      .read(settingsProvider.notifier)
                      .setShowAlbumArtInPlayer(value);
                },
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Storage',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  width: 0.5,
                ),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                leading: _isCacheLoading
                    ? SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.cleaning_services_rounded,
                        color: Theme.of(context).iconTheme.color,
                      ),
                title: const Text(
                  'Clear Cache',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  _cacheSizeBytes > 0
                      ? 'Waveform cache: ${CacheService.formatSize(_cacheSizeBytes)}'
                      : 'Waveform cache is empty',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                trailing: Icon(
                  Icons.delete_outline_rounded,
                  color: _cacheSizeBytes > 0
                      ? Colors.red.shade400
                      : Theme.of(context).disabledColor,
                ),
                enabled: !_isCacheLoading,
                onTap: _cacheSizeBytes > 0 && !_isCacheLoading
                    ? _clearCache
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showColorPickerDialog(BuildContext context, Color initialColor) {
    Color pickerColor = initialColor;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          backgroundColor: context.colors.bgCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Pick a color',
            style: TextStyle(color: context.colors.textPrimary),
          ),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              colorPickerWidth: 300,
              pickerAreaHeightPercent: 0.8,
              enableAlpha: false,
              displayThumbColor: true,
              paletteType: PaletteType.hsvWithHue,
              pickerAreaBorderRadius: const BorderRadius.all(
                Radius.circular(8),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(settingsProvider.notifier)
                    .setCustomPrimaryColor(pickerColor);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Color updated successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: context.colors.bgDarkest,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Save',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
