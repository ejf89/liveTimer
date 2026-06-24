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
                // Expanded: full name (the bottom region is full-width, so the whole name
                // fits — the narrow leading slot would truncate it). Below, time + controls in
                // a left column with the progress ring centered against it on the right. The
                // "Paused" badge sits inline at the end of the name line so it reads as part of
                // the layout rather than floating in a separate region by the camera.
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 5) {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(.orange)
                            Text(context.attributes.sessionName)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                            if context.state.isPaused {
                                Spacer(minLength: 6)
                                Label("Paused", systemImage: "pause.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                ElapsedText(state: context.state)
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .layoutPriority(1)
                                // Compact (icon-only, small) controls so the buttons fit the
                                // expanded island's height without clipping its rounded bottom.
                                if #available(iOS 17.0, *) {
                                    TimerControls(context: context, compact: true)
                                }
                            }
                            Spacer(minLength: 8)
                            ProgressRing(context: context)
                                .frame(width: 48, height: 48)
                        }
                    }
                    // Inset from the island's rounded corners so the name and ring
                    // (which sit at the far left/right) aren't clipped by the curve.
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                // Spec: compact shows the (truncated) session name. The slot flanking the
                // camera is narrow, so cap the width and let it truncate — the full,
                // untruncated name lives in the expanded + lock-screen views.
                HStack(spacing: 3) {
                    if context.state.isPaused {
                        Image(systemName: "pause.fill").foregroundStyle(.orange)
                    }
                    Text(context.attributes.sessionName)
                        .lineLimit(1)
                        .frame(maxWidth: 62)
                }
            } compactTrailing: {
                ElapsedText(state: context.state)
                    .monospacedDigit()
                    .foregroundStyle(context.state.isPaused ? .orange : .primary)
            } minimal: {
                // Minimal: just the elapsed time.
                ElapsedText(state: context.state)
                    .monospacedDigit()
            }
            .keylineTint(.orange)
        }
    }
}

/// Lock-screen / banner presentation.
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
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)
            GoalProgressBar(context: context)
            if #available(iOS 17.0, *) {
                TimerControls(context: context).padding(.top, 2)
            }
        }
    }
}

/// Renders elapsed time. While running it uses SwiftUI's native timer rendering so
/// iOS ticks it on-device with no updates; while paused it shows the frozen value in
/// the same M:SS / H:MM:SS shape, so the format never jumps between the two states.
@available(iOS 16.2, *)
private struct ElapsedText: View {
    let state: StudyAttributes.ContentState

    var body: some View {
        if state.isPaused {
            // Match the native running format (Text(timerInterval:) renders M:SS / H:MM:SS),
            // so pausing doesn't jump the layout from "0:29" to "00:00:29".
            Text(formatCompact(state.pausedElapsed))
        } else {
            // Bound the interval to 24h. `Text(timerInterval:)` reserves width for the whole
            // range, so an unbounded (distantFuture) range degrades to "M:--" at larger fonts;
            // a bounded range reserves a sane width and renders the running clock natively.
            // (A sub-1h cap to shrink the compact width drops the leading digit — ":05" — so
            // the same 24h bound is used everywhere for correct rendering.)
            Text(
                timerInterval: state.startAnchor ... state.startAnchor.addingTimeInterval(86400),
                countsDown: false
            )
        }
    }
}

/// Linear goal progress. Running uses timerInterval so the fill animates natively;
/// paused shows a static fraction. Used on the lock screen (the mockup uses a bar).
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
                    timerInterval: context.state.startAnchor ... (context.state.startAnchor + goal),
                    countsDown: false
                )
                .tint(.orange)
                .labelsHidden()
            }
        }
    }
}

/// Circular goal ring for the expanded Dynamic Island. iOS has no native
/// timer-driven circular progress, so this is a determinate snapshot evaluated at
/// each render/update (accurate when shown; it doesn't creep between updates).
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

/// Interactive Pause/Resume + Stop controls, driven by App Intents (iOS 17+) so the
/// timer can be controlled straight from the Live Activity without opening the app.
@available(iOS 17.0, *)
private struct TimerControls: View {
    let context: ActivityViewContext<StudyAttributes>
    /// Island uses icon-only/small controls (tight height); lock screen uses full labels.
    var compact = false

    var body: some View {
        // `.labelStyle` takes a concrete style type, so the icon-only vs. labelled choice
        // has to branch at the view level rather than via a ternary (the two styles are
        // different types and can't unify in one expression).
        if compact {
            controlStack.labelStyle(.iconOnly)
        } else {
            controlStack.labelStyle(.titleAndIcon)
        }
    }

    private var controlStack: some View {
        HStack(spacing: compact ? 8 : 10) {
            if context.state.isPaused {
                Button(intent: TimerControlIntent(action: "resume", activityId: context.activityID)) {
                    Label("Resume", systemImage: "play.fill")
                }
                .tint(.green)
            } else {
                Button(intent: TimerControlIntent(action: "pause", activityId: context.activityID)) {
                    Label("Pause", systemImage: "pause.fill")
                }
                .tint(.orange)
            }
            Button(intent: TimerControlIntent(action: "stop", activityId: context.activityID)) {
                Label("Stop", systemImage: "stop.fill")
            }
            .tint(.red)
        }
        .controlSize(compact ? .small : .regular)
        .buttonStyle(.borderedProminent)
        .font(.caption)
    }
}

func formatCompact(_ seconds: TimeInterval) -> String {
    let total = Int(max(0, seconds))
    let h = total / 3600, m = (total % 3600) / 60, s = total % 60
    return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
}
