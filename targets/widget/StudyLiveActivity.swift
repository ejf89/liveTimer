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
                            if hasReachedGoal(context) {
                                Spacer(minLength: 6)
                                Label("Goal reached", systemImage: "checkmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                                    .labelStyle(.titleAndIcon)
                            } else if context.state.isPaused {
                                Spacer(minLength: 6)
                                Label("Paused", systemImage: "pause.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                                    .labelStyle(.titleAndIcon)
                            }
                        }
                        HStack(alignment: .center, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                ElapsedText(state: context.state, goalSeconds: context.attributes.goalSeconds)
                                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(hasReachedGoal(context) ? .green : .primary)
                                    .layoutPriority(1)
                                // Compact (icon-only, small) controls so the buttons fit the
                                // expanded island's height without clipping its rounded bottom.
                                if #available(iOS 17.0, *) {
                                    TimerControls(
                                        context: context,
                                        compact: true,
                                        goalReached: hasReachedGoal(context)
                                    )
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
                    if hasReachedGoal(context) {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    } else if context.state.isPaused {
                        Image(systemName: "pause.fill").foregroundStyle(.orange)
                    }
                    Text(context.attributes.sessionName)
                        .lineLimit(1)
                        .frame(maxWidth: 62)
                }
            } compactTrailing: {
                ElapsedText(state: context.state, goalSeconds: context.attributes.goalSeconds)
                    .monospacedDigit()
                    .foregroundStyle(
                        hasReachedGoal(context) ? .green : (context.state.isPaused ? .orange : .primary)
                    )
            } minimal: {
                // Minimal: just the elapsed time.
                ElapsedText(state: context.state, goalSeconds: context.attributes.goalSeconds)
                    .monospacedDigit()
                    .foregroundStyle(hasReachedGoal(context) ? .green : .primary)
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
                if hasReachedGoal(context) {
                    Label("Goal reached", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else if context.state.isPaused {
                    Label("Paused", systemImage: "pause.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ElapsedText(state: context.state, goalSeconds: context.attributes.goalSeconds)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(hasReachedGoal(context) ? .green : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
            GoalProgressBar(context: context)
            if #available(iOS 17.0, *) {
                TimerControls(context: context, goalReached: hasReachedGoal(context))
                    .padding(.top, 2)
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
    var goalSeconds: Double?

    var body: some View {
        if state.isPaused {
            // Match the native running format (Text(timerInterval:) renders M:SS / H:MM:SS),
            // so pausing doesn't jump the layout from "0:29" to "00:00:29".
            Text(formatCompact(state.pausedElapsed))
        } else {
            // Count up from the anchor, bounded to the goal — the timer stops there anyway.
            // The bound is what fixes the intermittent "M:--" / "1:--" on the lock screen:
            // Text(timerInterval:) reserves width for the WIDEST value its range can show, so a
            // 24h range reserves for "23:59:59" and degrades to placeholder digits at larger
            // fonts (worst in the first lock-screen snapshot, before live ticking kicks in).
            // A goal-tight range (e.g. "25:00") reserves only what it needs. `pauseTime` freezes
            // the value at the goal if the goal passes before the completion update lands. No
            // goal -> 24h bound so it simply counts on.
            let goalDate = goalSeconds.map { state.startAnchor.addingTimeInterval($0) }
            let upper = goalDate ?? state.startAnchor.addingTimeInterval(86400)
            Text(timerInterval: state.startAnchor ... upper, pauseTime: goalDate, countsDown: false)
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
            let tint: Color = hasReachedGoal(context) ? .green : .orange
            if context.state.isPaused {
                ProgressView(value: min(context.state.pausedElapsed, goal), total: goal)
                    .tint(tint)
            } else {
                ProgressView(
                    timerInterval: context.state.startAnchor ... (context.state.startAnchor + goal),
                    countsDown: false
                )
                .tint(tint)
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
        let reached = hasReachedGoal(context)
        let tint: Color = reached ? .green : .orange
        ZStack {
            Circle().stroke(tint.opacity(0.25), lineWidth: 6)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: reached ? "checkmark" : (context.state.isPaused ? "pause.fill" : "book.closed.fill"))
                .font(.caption)
                .foregroundStyle(tint)
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
    /// Once the goal is reached the session is finished, so only Stop is offered.
    var goalReached = false

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
            if !goalReached {
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

/// True once the session has reached its goal — the timer is at rest and the UI shows
/// "goal reached". Derived from the existing state (a session frozen at/after its goal),
/// so the bridge contract stays unchanged. The running clock freezes on-device via
/// `pauseTime`, so this reads true even before the app pushes its completion update.
@available(iOS 16.2, *)
func hasReachedGoal(_ context: ActivityViewContext<StudyAttributes>) -> Bool {
    guard let goal = context.attributes.goalSeconds, goal > 0 else { return false }
    let elapsed = context.state.isPaused
        ? context.state.pausedElapsed
        : Date().timeIntervalSince(context.state.startAnchor)
    return elapsed >= goal
}

// MARK: - Previews

/// Sample data lives here (not in StudyAttributes.swift) so the shared contract file stays
/// byte-identical to its bridge-pod copy. These #Previews render each presentation in
/// isolation in Xcode's canvas — notably the `minimal` Dynamic Island, which the simulator
/// never shows at runtime (iOS only renders minimal when 2+ apps have active Live Activities).
@available(iOS 16.2, *)
private extension StudyAttributes {
    static var preview: StudyAttributes {
        StudyAttributes(sessionId: "preview", sessionName: "Chapter 5 Review", goalSeconds: 1500)
    }
}

@available(iOS 16.2, *)
private extension StudyAttributes.ContentState {
    static var running: StudyAttributes.ContentState {
        .init(startAnchor: Date().addingTimeInterval(-95), isPaused: false, pausedElapsed: 0)
    }

    static var paused: StudyAttributes.ContentState {
        .init(startAnchor: Date().addingTimeInterval(-95), isPaused: true, pausedElapsed: 95)
    }

    static var goalReached: StudyAttributes.ContentState {
        .init(startAnchor: Date().addingTimeInterval(-1500), isPaused: true, pausedElapsed: 1500)
    }
}

@available(iOS 17.0, *)
#Preview("Lock screen", as: .content, using: StudyAttributes.preview) {
    StudyLiveActivity()
} contentStates: {
    StudyAttributes.ContentState.running
    StudyAttributes.ContentState.paused
    StudyAttributes.ContentState.goalReached
}

@available(iOS 17.0, *)
#Preview("Dynamic Island (compact)", as: .dynamicIsland(.compact), using: StudyAttributes.preview) {
    StudyLiveActivity()
} contentStates: {
    StudyAttributes.ContentState.running
    StudyAttributes.ContentState.goalReached
}

@available(iOS 17.0, *)
#Preview("Dynamic Island (expanded)", as: .dynamicIsland(.expanded), using: StudyAttributes.preview) {
    StudyLiveActivity()
} contentStates: {
    StudyAttributes.ContentState.running
    StudyAttributes.ContentState.paused
    StudyAttributes.ContentState.goalReached
}

@available(iOS 17.0, *)
#Preview("Dynamic Island (minimal)", as: .dynamicIsland(.minimal), using: StudyAttributes.preview) {
    StudyLiveActivity()
} contentStates: {
    StudyAttributes.ContentState.running
    StudyAttributes.ContentState.goalReached
}
