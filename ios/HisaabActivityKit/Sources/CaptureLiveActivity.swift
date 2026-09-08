import ActivityKit
import Foundation

public struct HisaabCaptureAttributes: ActivityAttributes {
  public init() {}

  public struct ContentState: Codable, Hashable {
    public var preview: String
    public var status: String

    public init(preview: String, status: String) {
      self.preview = preview
      self.status = status
    }
  }
}

@available(iOS 16.2, *)
public enum CaptureLiveActivity {
  @discardableResult
  public static func present(preview: String) -> Bool {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else { return false }

    let clip = preview.trimmingCharacters(in: .whitespacesAndNewlines)
    let state = HisaabCaptureAttributes.ContentState(
      preview: clip,
      status: "ask"
    )

    for activity in Activity<HisaabCaptureAttributes>.activities {
      Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    let content = ActivityContent(
      state: state,
      staleDate: Date().addingTimeInterval(180)
    )
    do {
      _ = try Activity.request(
        attributes: HisaabCaptureAttributes(),
        content: content,
        pushType: nil
      )
      return true
    } catch {
      return false
    }
  }

  public static func finish(success: Bool) async {
    let state = HisaabCaptureAttributes.ContentState(
      preview: "",
      status: success ? "logged" : "empty"
    )
    let content = ActivityContent(state: state, staleDate: nil)
    for activity in Activity<HisaabCaptureAttributes>.activities {
      await activity.update(content)
    }
    try? await Task.sleep(nanoseconds: 1_600_000_000)
    for activity in Activity<HisaabCaptureAttributes>.activities {
      await activity.end(content, dismissalPolicy: .default)
    }
  }
}
