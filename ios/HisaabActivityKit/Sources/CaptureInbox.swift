import Foundation

public enum CaptureInbox {
  public static let suiteName = "group.com.arham.hisaab"
  public static let textKey = "hisaab.pendingImportText"
  public static let kindKey = "hisaab.pendingKind"
  public static let didStash = Notification.Name("hisaab.didStashCapture")

  public static var defaults: UserDefaults {
    UserDefaults(suiteName: suiteName) ?? .standard
  }

  public static func spendText(amount: Double) -> String? {
    guard amount.isFinite, amount > 0 else { return nil }
    let whole = amount.rounded(.towardZero)
    if whole == amount {
      return "Rs.\(Int(whole)) spent"
    }
    return String(format: "Rs.%.2f spent", amount)
  }

  @discardableResult
  public static func stashSpend(amount: Double) -> String? {
    guard let text = spendText(amount: amount) else { return nil }
    stash(kind: "import", text: text)
    return text
  }

  public static func stash(kind: String, text: String) {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    defaults.set(trimmed, forKey: textKey)
    defaults.set(kind, forKey: kindKey)
    defaults.synchronize()
    NotificationCenter.default.post(name: didStash, object: nil)
  }

  public static func take() -> (kind: String, text: String)? {
    let text = defaults.string(forKey: textKey) ?? ""
    let kind = defaults.string(forKey: kindKey)
    let resolved = kind ?? (text.isEmpty ? nil : "import")
    guard let resolved else { return nil }
    defaults.removeObject(forKey: textKey)
    defaults.removeObject(forKey: kindKey)
    defaults.synchronize()
    return (resolved, text)
  }
}
