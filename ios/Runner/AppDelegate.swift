import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Started before any FlutterViewController loads — avoids ProMotion
  /// VSyncClient SIGSEGV when the implicit engine shell is still nil.
  let flutterEngine = FlutterEngine(name: "hisaab")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
