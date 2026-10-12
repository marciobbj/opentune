import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SingleInstanceService {
  static const int _port = 48765;
  static const String _lockFileName = 'opentune_player.lock';

  RandomAccessFile? _lockHandle;
  ServerSocket? _server;
  Future<void> Function()? _onShowRequested;
  bool _windowReady = false;
  bool _pendingShow = false;

  Future<bool> acquire() async {
    final lockFile = File('${Directory.systemTemp.path}/$_lockFileName');
    _lockHandle = await lockFile.open(mode: FileMode.write);

    try {
      await _lockHandle!.lock(FileLock.exclusive);
    } catch (_) {
      await _lockHandle?.close();
      _lockHandle = null;
      return false;
    }

    // The file lock above is what guarantees a single instance. The socket is
    // only used to let a second launch ask this instance to show its window,
    // so a bind failure (e.g. sandbox restrictions, port in use) must not
    // prevent the app from starting.
    try {
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        _port,
        shared: false,
      );
      _server!.listen(_handleClient);
    } catch (_) {
      await _server?.close();
      _server = null;
    }
    return true;
  }

  void setOnShowRequested(Future<void> Function() handler) {
    _onShowRequested = handler;
    _flushPendingShow();
  }

  void markWindowReady() {
    _windowReady = true;
    _flushPendingShow();
  }

  Future<void> requestExistingInstanceToShow() async {
    for (var attempt = 0; attempt < 10; attempt++) {
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          _port,
          timeout: const Duration(milliseconds: 250),
        );
        socket.write('SHOW\n');
        await socket.flush();
        await socket.close();
        return;
      } catch (_) {
        if (attempt == 9) return;
        await Future<void>.delayed(const Duration(milliseconds: 150));
      }
    }
  }

  Future<void> _handleClient(Socket client) async {
    try {
      final message = await client
          .map<List<int>>((bytes) => bytes)
          .transform(utf8.decoder)
          .join();
      if (message.contains('SHOW')) {
        _pendingShow = true;
        _flushPendingShow();
      }
    } finally {
      client.destroy();
    }
  }

  void _flushPendingShow() {
    if (!_windowReady || !_pendingShow || _onShowRequested == null) return;
    _pendingShow = false;
    unawaited(_onShowRequested!());
  }

  Future<void> dispose() async {
    await _server?.close();
    _server = null;
    try {
      await _lockHandle?.unlock();
    } catch (_) {}
    await _lockHandle?.close();
    _lockHandle = null;
  }
}

final singleInstanceService = SingleInstanceService();
