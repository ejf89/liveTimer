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
                // Expanded: full session name, large ticking time, progress ring.
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "book.closed.fill")
                        .foregroundStyle(.orange)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Label("Paused", systemImage: "pause.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .labelStyle(.titleAndIcon)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(context.attributes.sessionName)
                            .font(.headline)
                            .lineLimit(1)
                        HStack(alignment: .center) {
                            ElapsedText(state: context.state)
                                .font(.system(size: 34, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .layoutPriority(1)
                            Spacer(minLength: 8)
                            ProgressRing(context: context)
                                .frame(width: 52, height: 52)
                        }
                    }
                }
            } compactLeading: {
                // Icon (book / pause). The compact island can't fit a readable name AND a
                // full timer, so the name lives in the expanded + lock-screen views.
                Image(systemName: context.state.isPaused ? "pause.fill" : "book.closed.fill")
                    .foregroundStyle(context.state.isPaused ? .orange : .primary)
            } compactTrailing: {
                ElapsedText(state: context.state, compact: true)
                    .monospacedDigit()
            } minimal: {
                // Minimal: just the elapsed time.
                ElapsedText(state: context.state, compact: true)
                    .monospacedDigit()
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
        VStack(alignment: .leading, spacing: 10) {
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
// `compact` drops the hours segment when zero, for the narrow Dynamic Island slots.
@available(iOS 16.2, *)
private struct ElapsedText: View {
    let state: StudyAttributes.ContentState
    var compact = false

    var body: some View {
        if state.isPaused {
            Text(compact ? formatCompact(state.pausedElapsed) : formatHHMMSS(state.pausedElapsed))
        } else {
            Text(timerInterval: state.startAnchor...Date.distantFuture, countsDown: false)
        }
    }
}

// Linear goal progress. Running uses timerInterval so the fill animates natively;
// paused shows a static fraction. Used on the lock screen (the mockup uses a bar).
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

// Circular goal ring for the expanded Dynamic Island. iOS has no native
// timer-driven circular progress, so this is a determinate snapshot evaluated at
// each render/update (accurate when shown; it doesn't creep between updates).
@available(iOS 16.2, *)
private struct ProgressRing: View {
    let context: ActivityViewContext<StudyAttributes>

    private var progress: Double {
        guard let goal = context.attributes.goalSeconds, goal > 0 else { return 0 }
        let elapsed = context.state.isPaused
            ? context.state.pausedElapsed
            : Date().timeIntervalSince(context.state.startAnchor)
        return min(max(elapsed / goal, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle().stroke(Color.orange.opacity(0.25), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: context.state.isPaused ? "pause.fill" : "book.closed.fill")
                .font(.caption)
                .foregroundStyle(.orange)
        }
    }
}

func formatHHMMSS(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    return String(format: "%02d:%02d:%02d", total / 3600, (total % 3600) / 60, total % 60)
}

func formatCompact(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
