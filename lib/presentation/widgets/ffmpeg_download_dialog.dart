import 'package:flutter/material.dart';

import '../../core/utils/ffmpeg_manager.dart';

/// A dialog that prompts the user to download FFmpeg when it's missing.
///
/// Shows a simple AlertDialog with Download/Cancel options.
/// During download, shows a progress indicator.
/// On failure, shows error with retry option.
class FfmpegDownloadDialog extends StatefulWidget {
  const FfmpegDownloadDialog({super.key});

  /// Show the dialog and return true if FFmpeg became available.
  static Future<bool> show(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const FfmpegDownloadDialog(),
    );
    return result ?? false;
  }

  @override
  State<FfmpegDownloadDialog> createState() => _FfmpegDownloadDialogState();
}

enum _DialogState { prompt, downloading, success, error }

class _FfmpegDownloadDialogState extends State<FfmpegDownloadDialog> {
  _DialogState _state = _DialogState.prompt;
  double _progress = 0.0;
  String? _errorMessage;

  Future<void> _startDownload() async {
    setState(() {
      _state = _DialogState.downloading;
      _progress = 0.0;
      _errorMessage = null;
    });

    final result = await FfmpegManager.instance.download(
      onProgress: (p) {
        if (mounted) {
          setState(() => _progress = p < 0 ? -1 : p);
        }
      },
    );

    if (!mounted) return;

    if (result != null) {
      setState(() => _state = _DialogState.success);
      // Brief pause to show success, then close
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      setState(() {
        _state = _DialogState.error;
        _errorMessage =
            'Download or extraction failed. Check your internet connection.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Text(_title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_message, style: theme.textTheme.bodyMedium),
            if (_state == _DialogState.downloading) ...[
              const SizedBox(height: 20),
              _progress < 0
                  ? const LinearProgressIndicator()
                  : LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _progress < 0
                    ? 'Downloading...'
                    : 'Downloading... ${(_progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_state == _DialogState.error && _errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ],
            if (_state == _DialogState.success) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'FFmpeg installed successfully!',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: _buildActions(context),
    );
  }

  String get _title {
    switch (_state) {
      case _DialogState.prompt:
        return 'FFmpeg Required';
      case _DialogState.downloading:
        return 'Downloading FFmpeg';
      case _DialogState.success:
        return 'Complete';
      case _DialogState.error:
        return 'Download Failed';
    }
  }

  String get _message {
    switch (_state) {
      case _DialogState.prompt:
        return 'OpenTune needs FFmpeg for waveform extraction on this platform. '
            'Would you like to download it now?\n\n'
            'This is a one-time setup (~30 MB).';
      case _DialogState.downloading:
        return 'Please wait while FFmpeg is being downloaded and installed.';
      case _DialogState.success:
        return 'FFmpeg has been set up successfully.';
      case _DialogState.error:
        return 'Something went wrong during the FFmpeg download.';
    }
  }

  List<Widget> _buildActions(BuildContext context) {
    switch (_state) {
      case _DialogState.prompt:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: _startDownload,
            child: const Text('Download'),
          ),
        ];
      case _DialogState.downloading:
        return [
          // No cancel during download to avoid partial state
          const SizedBox.shrink(),
        ];
      case _DialogState.success:
        return [const SizedBox.shrink()];
      case _DialogState.error:
        return [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Skip'),
          ),
          FilledButton(onPressed: _startDownload, child: const Text('Retry')),
        ];
    }
  }
}
