import AppIntents
import UIKit

/// Lets users run “Log payment from clipboard” from Shortcuts / Back Tap / Siri.
@available(iOS 16.0, *)
struct LogClipboardPaymentIntent: AppIntent {
  static var title: LocalizedStringResource = "Log payment from clipboard"

  static var description = IntentDescription(
    "Opens HISAAB with the text you copied (bank or wallet SMS) so it can log the payment."
  )

  /// Bring HISAAB forward so the hisaab:// deep link is handled by Flutter.
  static var openAppWhenRun: Bool = true

  func perform() async throws -> some IntentResult & ProvidesDialog {
    let text = await MainActor.run {
      UIPasteboard.general.string?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    guard !text.isEmpty else {
      return .result(
        dialog: "Copy a payment SMS first, then double-tap the back of your iPhone again."
      )
    }

    var allowed = CharacterSet.urlQueryAllowed
    allowed.remove(charactersIn: ":#[]@!$&'()*+,;=")
    guard
      let encoded = text.addingPercentEncoding(withAllowedCharacters: allowed),
      let url = URL(string: "hisaab://import?text=\(encoded)")
    else {
      return .result(dialog: "Could not build the import link from that text.")
    }

    await MainActor.run {
      UIApplication.shared.open(url, options: [:], completionHandler: nil)
    }

    return .result(dialog: "Sending to HISAAB…")
  }
}

@available(iOS 16.0, *)
struct HisaabAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: LogClipboardPaymentIntent(),
      phrases: [
        "Log payment in \(.applicationName)",
        "Add expense to \(.applicationName)",
        "Log clipboard in \(.applicationName)",
      ],
      shortTitle: "Log from clipboard",
      systemImageName: "clipboard"
    )
  }
}
