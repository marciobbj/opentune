import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/update_service.dart';

class UpdateState {
  final UpdateCheckResult result;
  final bool isDownloading;
  final double downloadProgress;

  const UpdateState({
    required this.result,
    this.isDownloading = false,
    this.downloadProgress = 0.0,
  });

  bool get isChecking => result.status == UpdateStatus.checking;
  bool get isUpdateAvailable => result.isUpdateAvailable;
  String get currentVersion => result.currentVersion;
  String? get latestVersion => result.latestVersion;

  UpdateState copyWith({
    UpdateCheckResult? result,
    bool? isDownloading,
    double? downloadProgress,
  }) {
    return UpdateState(
      result: result ?? this.result,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadProgress: downloadProgress ?? this.downloadProgress,
    );
  }
}

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier()
      : super(
          const UpdateState(
            result: UpdateCheckResult(
              status: UpdateStatus.checking,
              currentVersion: '',
            ),
          ),
        ) {
    _initialize();
  }

  Future<void> _initialize() async {
    final currentVersion = await UpdateService.getCurrentVersion();
    state = state.copyWith(
      result: UpdateCheckResult(
        status: UpdateStatus.checking,
        currentVersion: currentVersion,
      ),
    );
    await checkForUpdates();
  }

  Future<void> checkForUpdates() async {
    final currentVersion = await UpdateService.getCurrentVersion();
    state = state.copyWith(
      result: UpdateCheckResult(
        status: UpdateStatus.checking,
        currentVersion: currentVersion,
        latestVersion: state.result.latestVersion,
        releaseUrl: state.result.releaseUrl,
        downloadUrl: state.result.downloadUrl,
        assetName: state.result.assetName,
        releaseNotes: state.result.releaseNotes,
      ),
    );

    final checkResult = await UpdateService.checkForUpdates();
    state = state.copyWith(result: checkResult);
  }

  Future<bool> startUpdate() async {
    if (state.isDownloading) return false;

    state = state.copyWith(isDownloading: true, downloadProgress: 0.0);
    final ok = await UpdateService.downloadAndLaunchUpdate(
      updateInfo: state.result,
      onProgress: (p) {
        state = state.copyWith(downloadProgress: p);
      },
    );
    state = state.copyWith(isDownloading: false, downloadProgress: 0.0);
    return ok;
  }

  Future<void> openReleasePage() async {
    await UpdateService.openUrl(
      state.result.releaseUrl ?? UpdateService.defaultReleasesPageUrl,
    );
  }
}

final updateProvider = StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});
