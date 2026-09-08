import AppIntents
import UIKit
import HisaabActivityKit

/// Shortcuts / Siri / Back Tap → HISAAB.
///
/// Message automation: set **Payment text** to Shortcut Input (logs in the background).
/// Back Tap: leave Payment text empty — iOS asks for the amount on top of
/// the current app. HISAAB does **not** come to the front.
@available(iOS 16.0, *)
struct LogClipboardPaymentIntent: AppIntent {
  static var title: LocalizedStringResource { "Log payment" }

  static var description: IntentDescription {
    IntentDescription(
      "Logs a payment. Back Tap asks for the amount without opening HISAAB. Message automation can pass the SMS."
    )
  }

  static var openAppWhenRun: Bool { false }

  @Parameter(
    title: "Payment text",
    description: "The SMS. Leave empty for Back Tap — you will be asked for the amount.",
    inputConnectionBehavior: .connectToPreviousIntentResult
  )
  var paymentText: String?

  @Parameter(
    title: "Amount in Rs",
    description: "Used when Payment text is empty (Back Tap).",
    requestValueDialog: IntentDialog("How much should HISAAB log?")
  )
  var amount: Double?

  static var parameterSummary: some ParameterSummary {
    Summary("Log payment") {
      \.$paymentText
    }
  }

  func perform() async throws -> some IntentResult {
    let fromParam = paymentText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

    if !fromParam.isEmpty {
      CaptureInbox.stash(kind: "import", text: fromParam)
      await _deliverToApp(fromParam)
      return .result()
    }

    // Back Tap / empty shortcut — ask for Rs on top of whatever app is open.
    // Do not bring HISAAB to the front.
    let value: Double
    if let existing = amount, existing.isFinite, existing > 0 {
      value = existing
    } else {
      value = try await $amount.requestValue(
        IntentDialog("How much should HISAAB log?")
      )
    }
    guard let text = CaptureInbox.stashSpend(amount: value) else {
      return .result()
    }
    await _deliverToApp(text)
    if #available(iOS 16.2, *) {
      _ = CaptureLiveActivity.present(preview: text)
      await CaptureLiveActivity.finish(success: true)
    }
    return .result()
  }

  private func _deliverToApp(_ text: String) async {
    await MainActor.run {
      if let app = UIApplication.shared.delegate as? AppDelegate {
        app.deliverImportText(text)
      }
    }
  }
}

@available(iOS 16.0, *)
struct HisaabAppShortcuts: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    var items: [AppShortcut] = [
      AppShortcut(
        intent: LogClipboardPaymentIntent(),
        phrases: [
          "Log payment in \(.applicationName)",
          "Add expense to \(.applicationName)",
          "Log clipboard in \(.applicationName)",
        ],
        shortTitle: "Log payment",
        systemImageName: "banknote"
      ),
    ]
    if #available(iOS 16.2, *) {
      items.append(
        AppShortcut(
          intent: AddAmountIslandIntent(),
          phrases: [
            "Add amount in \(.applicationName)",
            "Log amount in \(.applicationName)",
          ],
          shortTitle: "Add amount",
          systemImageName: "plus.circle"
        )
      )
    }
    return items
  }
}
