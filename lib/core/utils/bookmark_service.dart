import 'dart:io';
import 'package:flutter/services.dart';

/// Service for managing macOS security-scoped bookmarks.
///
/// On macOS, sandboxed apps lose access to user-selected files after restart.
/// Security-scoped bookmarks persist that access across app launches/rebuilds.
///
/// On non-macOS platforms, all methods are no-ops and return null/true.
class BookmarkService {
  static const _channel = MethodChannel('com.opentune/bookmarks');

  static bool get _isMacOS => Platform.isMacOS;

  /// Creates a security-scoped bookmark for a file path.
  /// Returns the bookmark data as a base64 string, or null on failure/non-macOS.
  static Future<String?> createBookmark(String filePath) async {
    if (!_isMacOS) return null;
    try {
      final result = await _channel.invokeMethod<String>('createBookmark', {
        'path': filePath,
      });
      return result;
    } on PlatformException catch (e) {
      // Log but don't crash — bookmark creation failure is non-fatal
      print(
        'BookmarkService: Failed to create bookmark for $filePath: ${e.message}',
      );
      return null;
    }
  }

  /// Resolves a bookmark and starts accessing the security-scoped resource.
  /// Returns the resolved file path, or null on failure.
  /// If the bookmark is stale, [onStaleBookmark] is called with the new bookmark data.
  static Future<String?> startAccessing(
    String bookmarkData, {
    Future<void> Function(String newBookmarkData)? onStaleBookmark,
  }) async {
    if (!_isMacOS) return null;
    try {
      final result = await _channel.invokeMethod<Map>(
        'startAccessingResource',
        {'bookmarkData': bookmarkData},
      );
      if (result == null) return null;

      final success = result['success'] as bool? ?? false;
      final path = result['path'] as String?;
      final isStale = result['isStale'] as bool? ?? false;
      final newBookmarkData = result['newBookmarkData'] as String?;

      // If bookmark was stale and we got a new one, notify the caller
      if (isStale && newBookmarkData != null && onStaleBookmark != null) {
        await onStaleBookmark(newBookmarkData);
      }

      if (success && path != null) {
        return path;
      }
      return null;
    } on PlatformException catch (e) {
      print(
        'BookmarkService: Failed to start accessing resource: ${e.message}',
      );
      return null;
    }
  }

  /// Stops accessing a security-scoped resource.
  static Future<void> stopAccessing(String filePath) async {
    if (!_isMacOS) return;
    try {
      await _channel.invokeMethod('stopAccessingResource', {'path': filePath});
    } on PlatformException catch (e) {
      print('BookmarkService: Failed to stop accessing resource: ${e.message}');
    }
  }
}
