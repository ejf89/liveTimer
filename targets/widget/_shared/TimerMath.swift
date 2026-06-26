import Foundation

/// The one native expression of the timer math, shared by the widget (rendering) and
/// the App Intent (`perform()` mutating the activity). Lives in `_shared/`, so it compiles
/// into both the widget extension and the app target alongside the intent.
///
/// This is the Swift half of a deliberate two-runtime duplication: the same anchor math
/// exists in TypeScript (`lib/timer.ts`) because the App Intent runs without a JS runtime
/// and ActivityKit renders without one either. There is no third copy — both the widget and
/// the intent funnel through here.
extension StudyAttributes.ContentState {
    /// Elapsed seconds as of `now`: the frozen value while paused, derived from the
    /// anchor while running. Time is always derived from `startAnchor`, never stored.
    func elapsed(asOf now: Date = Date()) -> TimeInterval {
        isPaused ? pausedElapsed : now.timeIntervalSince(startAnchor)
    }
}

extension StudyAttributes {
    /// True once the session has reached its goal. Derived from existing state (no new
    /// ContentState field), so the bridge/attributes contract stays unchanged. A goal of
    /// nil / non-positive means "no goal" and never completes.
    func hasReachedGoal(_ state: ContentState, asOf now: Date = Date()) -> Bool {
        guard let goal = goalSeconds, goal > 0 else { return false }
        return state.elapsed(asOf: now) >= goal
    }
}
