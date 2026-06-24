import ActivityKit
import AppIntents
import Foundation

/// Interactive Live Activity control (iOS 17+). Lives in `_shared` so it compiles
/// into BOTH the widget (which references it in `Button(intent:)`) and the app
/// (where `perform()` runs — the system launches the app in the background, no UI).
///
/// The intent mutates the Live Activity directly in Swift, mirroring the JS anchor
/// math. When the user later opens the app, useTimer's launch reconciliation reads
/// the (already-updated) activity state via getActiveSessions and stays in sync.
@available(iOS 17.0, *)
struct TimerControlIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Control Study Timer"

    @Parameter(title: "Action") var action: String
    @Parameter(title: "Activity ID") var activityId: String

    init() {}

    init(action: String, activityId: String) {
        self.action = action
        self.activityId = activityId
    }

    func perform() async throws -> some IntentResult {
        guard let activity = Activity<StudyAttributes>.activities.first(where: { $0.id == activityId })
        else {
            return .result()
        }

        let state = activity.content.state
        let now = Date()

        switch action {
        case "pause":
            let pausedElapsed = now.timeIntervalSince(state.startAnchor)
            let next = StudyAttributes.ContentState(
                startAnchor: state.startAnchor,
                isPaused: true,
                pausedElapsed: pausedElapsed
            )
            await activity.update(ActivityContent(state: next, staleDate: nil))
        case "resume":
            let next = StudyAttributes.ContentState(
                startAnchor: now.addingTimeInterval(-state.pausedElapsed),
                isPaused: false,
                pausedElapsed: state.pausedElapsed
            )
            await activity.update(ActivityContent(state: next, staleDate: nil))
        case "stop":
            await activity.end(nil, dismissalPolicy: .immediate)
        default:
            break
        }

        return .result()
    }
}
