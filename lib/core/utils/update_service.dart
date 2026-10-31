import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

enum UpdateStatus {
  checking,
  upToDate,
  updateAvailable,
  offlineOrUnavailable,
}

class UpdateCheckResult {
  final UpdateStatus status;
  final String currentVersion;
  final String? latestVersion;
  final String? releaseUrl;
  final String? downloadUrl;
  final String? assetName;
  final String? releaseNotes;

  const UpdateCheckResult({
    required this.status,
    required this.currentVersion,
    this.latestVersion,
    this.releaseUrl,
    this.downloadUrl,
    this.assetName,
    this.releaseNotes,
  });

  bool get isUpdateAvailable => status == UpdateStatus.updateAvailable;
}

class UpdateService {
  static const String _repoOwner = 'marciobbj';
  static const String _repoName = 'opentune';
  static const String _latestReleaseApiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';
  static const String defaultReleasesPageUrl =
      'https://github.com/$_repoOwner/$_repoName/releases/latest';

  static String? _cachedCurrentVersion;

  /// Reads the current application version from bundled `pubspec.yaml`.
  static Future<String> getCurrentVersion() async {
    if (_cachedCurrentVersion != null) return _cachedCurrentVersion!;
    try {
      final pubspec = await rootBundle.loadString('pubspec.yaml');
      final parsed = _extractVersionFromPubspec(pubspec);
      if (parsed != null) {
        _cachedCurrentVersion = parsed;
        return _cachedCurrentVersion!;
      }
    } catch (e) {
      debugPrint('UpdateService: could not read bundled pubspec.yaml: $e');
    }

    try {
      final file = File('pubspec.yaml');
      if (await file.exists()) {
        final parsed = _extractVersionFromPubspec(await file.readAsString());
        if (parsed != null) {
          _cachedCurrentVersion = parsed;
          return _cachedCurrentVersion!;
        }
      }
    } catch (_) {}

    return '';
  }

  static String? _extractVersionFromPubspec(String pubspecContent) {
    final match = RegExp(
      r'^version:\s*([^\s#]+)',
      multiLine: true,
    ).firstMatch(pubspecContent);
    if (match == null) return null;
    return normalizeVersion(match.group(1)!);
  }

  /// Strips leading `v`/`V` and build metadata (`+123`).
  static String normalizeVersion(String version) {
    var cleaned = version.trim();
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex != -1) {
      cleaned = cleaned.substring(0, plusIndex);
    }
    return cleaned.trim();
  }

  /// Returns `true` if [latest] is strictly newer than [current].
  static bool isNewerVersion(String current, String latest) {
    final currentParts = _parseVersionParts(current);
    final latestParts = _parseVersionParts(latest);
    if (currentParts.isEmpty || latestParts.isEmpty) return false;

    final maxLen = currentParts.length > latestParts.length
        ? currentParts.length
        : latestParts.length;

    for (var i = 0; i < maxLen; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final l = i < latestParts.length ? latestParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String version) {
    final normalized = normalizeVersion(version).split('-').first;
    final parts = <int>[];
    for (final segment in normalized.split('.')) {
      final parsed = int.tryParse(segment);
      if (parsed == null) return const [];
      parts.add(parsed);
    }
    return parts;
  }

  /// Queries GitHub Releases for the latest version.
  /// If there is no internet connection or the API fails, degrades gracefully
  /// by returning [UpdateStatus.offlineOrUnavailable] with [currentVersion].
  static Future<UpdateCheckResult> checkForUpdates() async {
    final currentVersion = await getCurrentVersion();

    if (kIsWeb || currentVersion.isEmpty) {
      return UpdateCheckResult(
        status: UpdateStatus.offlineOrUnavailable,
        currentVersion: currentVersion,
      );
    }

    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 6);

    try {
      final request = await client
          .getUrl(Uri.parse(_latestReleaseApiUrl))
          .timeout(const Duration(seconds: 6));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'OpenTune/$currentVersion');

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return UpdateCheckResult(
          status: UpdateStatus.offlineOrUnavailable,
          currentVersion: currentVersion,
        );
      }

      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 6));
      final data = jsonDecode(body) as Map<String, dynamic>;

      final rawTag = (data['tag_name'] as String?) ?? (data['name'] as String?);
      if (rawTag == null || rawTag.trim().isEmpty) {
        return UpdateCheckResult(
          status: UpdateStatus.offlineOrUnavailable,
          currentVersion: currentVersion,
        );
      }

      final latestVersion = normalizeVersion(rawTag);
      final releaseUrl =
          (data['html_url'] as String?) ?? defaultReleasesPageUrl;
      final releaseNotes = data['body'] as String?;

      final assets = (data['assets'] as List<dynamic>?) ?? const [];
      final matchedAsset = _selectPlatformAsset(assets);

      final newer = isNewerVersion(currentVersion, latestVersion);
      return UpdateCheckResult(
        status: newer ? UpdateStatus.updateAvailable : UpdateStatus.upToDate,
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        releaseUrl: releaseUrl,
        downloadUrl: matchedAsset?.$2,
        assetName: matchedAsset?.$1,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      debugPrint('UpdateService: update check skipped/offline ($e)');
      return UpdateCheckResult(
        status: UpdateStatus.offlineOrUnavailable,
        currentVersion: currentVersion,
      );
    } finally {
      client.close();
    }
  }

  /// Picks the preferred installer asset `(name, browser_download_url)` for the current OS.
  static (String, String)? _selectPlatformAsset(List<dynamic> assets) {
    final parsed = <(String, String)>[];
    for (final item in assets) {
      if (item is Map<String, dynamic>) {
        final name = item['name'] as String?;
        final url = item['browser_download_url'] as String?;
        if (name != null && url != null) {
          parsed.add((name, url));
        }
      }
    }
    if (parsed.isEmpty) return null;

    List<String> preferredNames = const [];
    if (Platform.isMacOS) {
      preferredNames = [
        'OpenTune-macOS.dmg',
        'OpenTune-macOS-Portable.zip',
        'macos-release.zip',
      ];
    } else if (Platform.isWindows) {
      preferredNames = [
        'OpenTune-Windows-Setup.exe',
        'OpenTune-Windows-Portable.zip',
        'windows-release.zip',
      ];
    } else if (Platform.isLinux) {
      preferredNames = [
        'OpenTune-Linux-Portable.zip',
        'linux-release.zip',
      ];
    }

    for (final candidate in preferredNames) {
      for (final asset in parsed) {
        if (asset.$1.toLowerCase() == candidate.toLowerCase()) {
          return asset;
        }
      }
    }

    // Fallback by extension on desktop
    if (Platform.isMacOS) {
      for (final asset in parsed) {
        if (asset.$1.toLowerCase().endsWith('.dmg')) return asset;
      }
    } else if (Platform.isWindows) {
      for (final asset in parsed) {
        if (asset.$1.toLowerCase().endsWith('.exe')) return asset;
      }
    }

    return null;
  }

  /// Downloads and launches the installer asset on Windows (`.exe`), or opens
  /// the direct asset download URL in the system browser on macOS (`.dmg`),
  /// falling back to the release page URL when no direct asset is available.
  ///
  /// Note: On macOS, downloading a `.dmg` directly inside the App Sandbox
  /// causes `Quarantine.kext` to stamp the file with `QTN_FLAG_SANDBOX`
  /// (`0x0086` - "created without user consent"), which propagates to the
  /// copied `.app` and blocks `posix_spawn` with `EPERM (-10810)`. Delegating
  /// the `.dmg` download to the system browser applies standard user-approved
  /// quarantine attributes so macOS allows launching the updated app.
  static Future<bool> downloadAndLaunchUpdate({
    required UpdateCheckResult updateInfo,
    void Function(double progress)? onProgress,
  }) async {
    final downloadUrl = updateInfo.downloadUrl;
    final assetName = updateInfo.assetName;

    if (!kIsWeb && Platform.isMacOS) {
      return openUrl(
        downloadUrl ?? updateInfo.releaseUrl ?? defaultReleasesPageUrl,
      );
    }

    final canDirectInstall = !kIsWeb &&
        Platform.isWindows &&
        downloadUrl != null &&
        assetName != null &&
        assetName.toLowerCase().endsWith('.exe');

    if (!canDirectInstall) {
      return openUrl(
        downloadUrl ?? updateInfo.releaseUrl ?? defaultReleasesPageUrl,
      );
    }

    final client = HttpClient();
    File? tmpFile;

    try {
      final tempDir = await getTemporaryDirectory();
      final outPath = path.join(tempDir.path, assetName);
      tmpFile = File('$outPath.part');
      final finalFile = File(outPath);

      if (await tmpFile.exists()) {
        await tmpFile.delete();
      }

      final request = await client.getUrl(Uri.parse(downloadUrl));
      request.headers.set(HttpHeaders.userAgentHeader, 'OpenTune-Updater');
      final response = await request.close();

      if (response.statusCode != 200) {
        client.close();
        return openUrl(updateInfo.releaseUrl ?? defaultReleasesPageUrl);
      }

      final totalBytes = response.contentLength;
      var receivedBytes = 0;

      final sink = tmpFile.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        receivedBytes += chunk.length;
        if (totalBytes > 0) {
          onProgress?.call(receivedBytes / totalBytes);
        } else {
          onProgress?.call(-1);
        }
      }
      await sink.flush();
      await sink.close();
      client.close();

      if (await finalFile.exists()) {
        await finalFile.delete();
      }
      await tmpFile.rename(finalFile.path);

      // Starts the Inno Setup wizard ("Seguinte -> Instalar -> Concluir")
      await Process.start(
        finalFile.path,
        const [],
        mode: ProcessStartMode.detached,
      );
      return true;
    } catch (e) {
      debugPrint('UpdateService: direct installer download failed ($e), opening browser');
      try {
        if (tmpFile != null && await tmpFile.exists()) {
          await tmpFile.delete();
        }
      } catch (_) {}
      return openUrl(updateInfo.releaseUrl ?? defaultReleasesPageUrl);
    } finally {
      client.close();
    }
  }

  /// Opens a URL in the user's default system browser.
  static Future<bool> openUrl(String url) async {
    try {
      if (Platform.isMacOS) {
        final res = await Process.run('open', [url]);
        return res.exitCode == 0;
      } else if (Platform.isWindows) {
        final res = await Process.run(
          'rundll32',
          ['url.dll,FileProtocolHandler', url],
        );
        return res.exitCode == 0;
      } else if (Platform.isLinux) {
        final res = await Process.run('xdg-open', [url]);
        return res.exitCode == 0;
      }
    } catch (e) {
      debugPrint('UpdateService: could not open URL $url ($e)');
    }
    return false;
  }
}
