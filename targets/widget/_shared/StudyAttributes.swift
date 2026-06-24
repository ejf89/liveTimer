import ActivityKit
import Foundation

/// Shared data contract for the Live Activity.
///
/// This file lives in `targets/widget/_shared/`, so @bacons/apple-targets links
/// it into BOTH the main app target AND the widget extension. The native bridge
/// (a separate Expo module pod) keeps an identical copy — ActivityKit matches an
/// Activity to its widget by the attributes type name + Codable shape, so the two
/// compiled copies interoperate. See DISCUSSION.md for this trade-off.
///
/// ⚠️ KEEP IN SYNC with modules/study-timer/ios/StudyAttributes.swift
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
