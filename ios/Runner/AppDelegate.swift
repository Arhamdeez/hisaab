import Flutter
import UIKit
import HisaabActivityKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Started before any FlutterViewController loads — avoids ProMotion
  /// VSyncClient SIGSEGV when the implicit engine shell is still nil.
  let flutterEngine = FlutterEngine(name: "hisaab")

  private var shortcutsChannel: FlutterMethodChannel?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    LocalStore.includeSqliteInBackup()
    _setupLocalStoreChannel()
    _setupShortcutsChannel()
    NotificationCenter.default.addObserver(
      forName: CaptureInbox.didStash,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?._flushInboxToFlutter()
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// SMS from Message automation / `hisaab://import`.
  func deliverImportText(_ text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    CaptureInbox.stash(kind: "import", text: trimmed)
    shortcutsChannel?.invokeMethod("importText", arguments: trimmed)
  }

  /// Back Tap island — does not bring the Flutter UI forward.
  @discardableResult
  func presentCaptureIsland(clipboard: String? = nil) -> Bool {
    let clip = (clipboard ?? UIPasteboard.general.string ?? "")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard #available(iOS 16.2, *) else { return false }
    return CaptureLiveActivity.present(preview: clip)
  }

  func deliverImportURL(_ url: URL) {
    guard url.scheme?.lowercased() == "hisaab" else { return }
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return
    }
    let host = (comps.host ?? "").lowercased()
    let path = comps.path.lowercased()
    let isCapture = host == "capture" || path == "/capture" || path == "capture"
    if isCapture {
      let items = comps.queryItems ?? []
      let raw = items.first(where: { $0.name == "text" })?.value
        ?? items.first(where: { $0.name == "body" })?.value
      _ = presentCaptureIsland(clipboard: raw)
      return
    }
    if let text = Self.importText(from: url) {
      deliverImportText(text)
    }
  }

  static func importText(from url: URL) -> String? {
    guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
      return nil
    }
    let host = (comps.host ?? "").lowercased()
    let path = comps.path.lowercased()
    let isImport = host == "import" || path == "/import" || path == "import"
      || (host.isEmpty && (path.isEmpty || path == "/"))
    guard url.scheme?.lowercased() == "hisaab", isImport || host.isEmpty else {
      return nil
    }
    let items = comps.queryItems ?? []
    let raw = items.first(where: { $0.name == "text" })?.value
      ?? items.first(where: { $0.name == "body" })?.value
    let text = raw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    return text.isEmpty ? nil : text
  }

  private func _flushInboxToFlutter() {
    let text = CaptureInbox.defaults.string(forKey: CaptureInbox.textKey) ?? ""
    let kind = CaptureInbox.defaults.string(forKey: CaptureInbox.kindKey)
    guard kind == "import" || (kind == nil && !text.isEmpty) else { return }
    guard !text.isEmpty else { return }
    shortcutsChannel?.invokeMethod("importText", arguments: text)
  }

  private func _setupLocalStoreChannel() {
    let storeChannel = FlutterMethodChannel(
      name: "com.arham.hisaab/local_store",
      binaryMessenger: flutterEngine.binaryMessenger
    )
    storeChannel.setMethodCallHandler { call, result in
      if call.method == "includeSqliteInBackup" ||
          call.method == "excludeSqliteFromBackup" {
        LocalStore.includeSqliteInBackup()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func _setupShortcutsChannel() {
    let channel = FlutterMethodChannel(
      name: "com.arham.hisaab/shortcuts",
      binaryMessenger: flutterEngine.binaryMessenger
    )
    shortcutsChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "takePending":
        if let pair = CaptureInbox.take() {
          result(["mode": pair.kind, "text": pair.text])
        } else {
          result(nil)
        }
      case "startIsland":
        let clip = call.arguments as? String
        result(self.presentCaptureIsland(clipboard: clip))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
