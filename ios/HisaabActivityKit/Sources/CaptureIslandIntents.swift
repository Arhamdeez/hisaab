import AppIntents
import UIKit

@available(iOS 16.2, *)
public struct LogCopiedSmsIntent: AppIntent {
  public init() {}

  public static var title: LocalizedStringResource { "Log copied SMS" }
  public static var description: IntentDescription {
    IntentDescription("Logs the payment SMS you copied, from the Dynamic Island.")
  }
  public static var openAppWhenRun: Bool { false }
  public static var isDiscoverable: Bool { false }

  public func perform() async throws -> some IntentResult {
    let text = await MainActor.run { () -> String in
      UIPasteboard.general.string?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
    guard !text.isEmpty else {
      await CaptureLiveActivity.finish(success: false)
      return .result()
    }
    CaptureInbox.stash(kind: "import", text: text)
    await CaptureLiveActivity.finish(success: true)
    return .result()
  }
}

@available(iOS 16.2, *)
public struct AddAmountIslandIntent: AppIntent {
  public init() {}

  public static var title: LocalizedStringResource { "Type an amount" }
  public static var description: IntentDescription {
    IntentDescription("Logs a spend amount from the Dynamic Island.")
  }
  public static var openAppWhenRun: Bool { false }
  public static var isDiscoverable: Bool { true }

  @Parameter(
    title: "Amount in Rs",
    description: "How much to log",
    requestValueDialog: IntentDialog("How much should HISAAB log?")
  )
  public var amount: Double

  public func perform() async throws -> some IntentResult {
    guard CaptureInbox.stashSpend(amount: amount) != nil else {
      await CaptureLiveActivity.finish(success: false)
      return .result()
    }
    await CaptureLiveActivity.finish(success: true)
    return .result()
  }
}
