import ActivityKit
import Foundation

/// ⚠️ SYNCED COPY of targets/widget/_shared/StudyAttributes.swift (the source of truth).
/// ActivityKit matches an Activity to its widget by the attributes type name + Codable
/// shape, so this copy (compiled into the bridge pod) and the widget copy must declare the
/// SAME struct shape — comments may differ, the declaration may not. A drift guard
/// (lib/attributesSync.test.ts) fails CI if the shapes diverge. See CLAUDE.md invariant 3.
struct StudyAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Effective start instant for the count-up timer (now - accumulatedElapsed).
        /// The widget renders elapsed time on-device from this anchor, so it ticks
        /// without any JS->native traffic, even backgrounded.
        var startAnchor: Date
        /// Whether the session is paused. When true the widget shows a frozen value.
        var isPaused: Bool
        /// Elapsed seconds frozen at the moment of pause (used for static display).
        var pausedElapsed: TimeInterval
    }

    /// Stable identifier for the session (also the Activity id we track in JS).
    var sessionId: String
    /// User-provided session name (fixed for the life of the session).
    var sessionName: String
    /// Optional study goal in seconds; drives the progress ring/bar when present.
    var goalSeconds: Double?
}
