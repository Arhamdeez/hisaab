import SwiftUI
import WidgetKit
import ActivityKit
import HisaabActivityKit

@main
struct HisaabIslandBundle: WidgetBundle {
  var body: some Widget {
    HisaabIslandLiveActivity()
  }
}

struct HisaabIslandLiveActivity: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: HisaabCaptureAttributes.self) { context in
      LockScreenBanner(state: context.state)
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          HisaabMarkView(size: 22)
        }
        DynamicIslandExpandedRegion(.center) {
          VStack(alignment: .leading, spacing: 2) {
            Text(context.state.status == "logged" ? "Logged" : "HISAAB")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
            Text(headline(context.state))
              .font(.subheadline.weight(.bold))
              .foregroundStyle(.white)
              .lineLimit(2)
              .minimumScaleFactor(0.85)
          }
        }
        DynamicIslandExpandedRegion(.bottom) {
          expandedBottom(context.state)
        }
      } compactLeading: {
        HisaabMarkView(size: 16)
      } compactTrailing: {
        Text(context.state.status == "logged" ? "OK" : "Add")
          .font(.caption.weight(.bold))
          .foregroundStyle(.white)
      } minimal: {
        HisaabMarkView(size: 14)
      }
      .widgetURL(nil)
      .keylineTint(Color(red: 0.91, green: 0.28, blue: 0.26))
    }
  }

  private func headline(_ state: HisaabCaptureAttributes.ContentState) -> String {
    switch state.status {
    case "logged":
      return "Saved to HISAAB"
    case "empty":
      return "Nothing to log"
    default:
      return "What do you want to add?"
    }
  }

  @ViewBuilder
  private func expandedBottom(_ state: HisaabCaptureAttributes.ContentState) -> some View {
    if state.status == "ask" {
      VStack(alignment: .leading, spacing: 8) {
        if !state.preview.isEmpty {
          Text(state.preview)
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.72))
            .lineLimit(2)
        }
        if #available(iOS 17.0, *) {
          HStack(spacing: 8) {
            Button(intent: LogCopiedSmsIntent()) {
              Text("Log SMS")
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
            }
            .tint(.white)
            .buttonStyle(.borderedProminent)

            Button(intent: AddAmountIslandIntent()) {
              Text("Amount")
                .font(.caption.weight(.bold))
                .frame(maxWidth: .infinity)
            }
            .tint(.white.opacity(0.22))
            .buttonStyle(.borderedProminent)
          }
        }
      }
    }
  }
}

private struct HisaabMarkView: View {
  var size: CGFloat

  var body: some View {
    Image("HisaabMark")
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
  }
}

private struct LockScreenBanner: View {
  let state: HisaabCaptureAttributes.ContentState

  var body: some View {
    HStack(spacing: 12) {
      HisaabMarkView(size: 28)
      VStack(alignment: .leading, spacing: 2) {
        Text("HISAAB")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
        Text(state.status == "logged" ? "Logged" : "What do you want to add?")
          .font(.subheadline.weight(.bold))
        if !state.preview.isEmpty, state.status == "ask" {
          Text(state.preview)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(2)
        }
      }
      Spacer(minLength: 0)
    }
    .padding(14)
  }
}
