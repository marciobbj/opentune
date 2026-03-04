import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    guard let controller = mainFlutterWindow?.contentViewController as? FlutterViewController else {
      return
    }

    let channel = FlutterMethodChannel(
      name: "com.opentune/bookmarks",
      binaryMessenger: controller.engine.binaryMessenger
    )

    channel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "createBookmark":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
          return
        }
        self.createBookmark(path: path, result: result)

      case "resolveBookmark":
        guard let args = call.arguments as? [String: Any],
              let bookmarkBase64 = args["bookmarkData"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing bookmarkData argument", details: nil))
          return
        }
        self.resolveBookmark(bookmarkBase64: bookmarkBase64, result: result)

      case "startAccessingResource":
        guard let args = call.arguments as? [String: Any],
              let bookmarkBase64 = args["bookmarkData"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing bookmarkData argument", details: nil))
          return
        }
        self.startAccessingResource(bookmarkBase64: bookmarkBase64, result: result)

      case "stopAccessingResource":
        guard let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing path argument", details: nil))
          return
        }
        self.stopAccessingResource(path: path, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func createBookmark(path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    do {
      let bookmarkData = try url.bookmarkData(
        options: .withSecurityScope,
        includingResourceValuesForKeys: nil,
        relativeTo: nil
      )
      let base64String = bookmarkData.base64EncodedString()
      result(base64String)
    } catch {
      result(FlutterError(
        code: "BOOKMARK_ERROR",
        message: "Failed to create bookmark: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func resolveBookmark(bookmarkBase64: String, result: @escaping FlutterResult) {
    guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
      result(FlutterError(code: "INVALID_DATA", message: "Invalid base64 bookmark data", details: nil))
      return
    }

    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      var newBookmarkBase64: String? = nil
      if isStale {
        // Re-create the bookmark since it's stale
        if let newData = try? url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        ) {
          newBookmarkBase64 = newData.base64EncodedString()
        }
      }

      result([
        "path": url.path,
        "isStale": isStale,
        "newBookmarkData": newBookmarkBase64 as Any
      ])
    } catch {
      result(FlutterError(
        code: "RESOLVE_ERROR",
        message: "Failed to resolve bookmark: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func startAccessingResource(bookmarkBase64: String, result: @escaping FlutterResult) {
    guard let bookmarkData = Data(base64Encoded: bookmarkBase64) else {
      result(FlutterError(code: "INVALID_DATA", message: "Invalid base64 bookmark data", details: nil))
      return
    }

    do {
      var isStale = false
      let url = try URL(
        resolvingBookmarkData: bookmarkData,
        options: .withSecurityScope,
        relativeTo: nil,
        bookmarkDataIsStale: &isStale
      )

      let success = url.startAccessingSecurityScopedResource()

      var newBookmarkBase64: String? = nil
      if isStale {
        if let newData = try? url.bookmarkData(
          options: .withSecurityScope,
          includingResourceValuesForKeys: nil,
          relativeTo: nil
        ) {
          newBookmarkBase64 = newData.base64EncodedString()
        }
      }

      result([
        "success": success,
        "path": url.path,
        "isStale": isStale,
        "newBookmarkData": newBookmarkBase64 as Any
      ])
    } catch {
      result(FlutterError(
        code: "ACCESS_ERROR",
        message: "Failed to start accessing resource: \(error.localizedDescription)",
        details: nil
      ))
    }
  }

  private func stopAccessingResource(path: String, result: @escaping FlutterResult) {
    let url = URL(fileURLWithPath: path)
    url.stopAccessingSecurityScopedResource()
    result(true)
  }
}
