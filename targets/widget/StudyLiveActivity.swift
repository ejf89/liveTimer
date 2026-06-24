import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct StudyLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StudyAttributes.self) { context in
            LockScreenView(context: context)
                .padding()
                .activityBackgroundTint(Color.black.opacity(0.35))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.attributes.sessionName, systemImage: "book.closed.fill")
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Image(systemName: "pause.fill").foregroundStyle(.orange)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ElapsedText(state: context.state)
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    GoalProgressBar(context: context)
                }
            } compactLeading: {
                Image(systemName: "book.closed.fill")
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .monospacedDigit()
                    .frame(width: 56)
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "book.closed.fill")
            }
            .keylineTint(.orange)
        }
    }
}

// Lock-screen / banner presentation.
@available(iOS 16.2, *)
private struct LockScreenView: View {
    let context: ActivityViewContext<StudyAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "book.closed.fill")
                Text(context.attributes.sessionName)
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                if context.state.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ElapsedText(state: context.state)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
            GoalProgressBar(context: context)
        }
    }
}

// Renders elapsed time. While running it uses SwiftUI's native timer rendering so
// iOS ticks it on-device with no updates; while paused it shows the frozen value.
@available(iOS 16.2, *)
private struct ElapsedText: View {
    let state: StudyAttributes.ContentState

    var body: some View {
        if state.isPaused {
            Text(formatHHMMSS(state.pausedElapsed))
        } else {
            Text(timerInterval: state.startAnchor...Date.distantFuture, countsDown: false)
        }
    }
}

// Linear progress toward the optional study goal. Running uses timerInterval so the
// fill animates natively; paused shows a static fraction.
@available(iOS 16.2, *)
private struct GoalProgressBar: View {
    let context: ActivityViewContext<StudyAttributes>

    var body: some View {
        if let goal = context.attributes.goalSeconds, goal > 0 {
            if context.state.isPaused {
                ProgressView(value: min(context.state.pausedElapsed, goal), total: goal)
                    .tint(.orange)
            } else {
                ProgressView(
                    timerInterval: context.state.startAnchor...(context.state.startAnchor + goal),
                    countsDown: false
                )
                .tint(.orange)
                .labelsHidden()
            }
        }
    }
}

func formatHHMMSS(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}
