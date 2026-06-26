import ActivityKit
import ExpoModulesCore
import os

/// Bridge between React Native and ActivityKit. The JS layer owns the timer state
/// machine; this module only translates typed calls into Live Activity lifecycle
/// operations. Async work runs in a Task that resolves the Promise; all ActivityKit
/// calls are gated on iOS 16.2+ (see CLAUDE.md invariants).
public class StudyTimerModule: Module {
    public func definition() -> ModuleDefinition {
        Name("StudyTimer")

        Function("areEnabled") { () -> Bool in
            if #available(iOS 16.2, *) {
                return LiveActivityController.areEnabled
            }
            return false
        }

        AsyncFunction("start") { (options: StartOptions, promise: Promise) in
            guard #available(iOS 16.2, *) else {
                promise.reject(LiveActivityUnavailableException())
                return
            }
            Task {
                do {
                    try promise.resolve(await LiveActivityController.start(options))
                } catch let exception as Exception {
                    promise.reject(exception)
                } catch {
                    promise.reject("ERR_LIVE_ACTIVITY", error.localizedDescription)
                }
            }
        }

        AsyncFunction("update") { (options: UpdateOptions, promise: Promise) in
            guard #available(iOS 16.2, *) else { promise.resolve(nil); return }
            Task {
                await LiveActivityController.update(options)
                promise.resolve(nil)
            }
        }

        AsyncFunction("end") { (id: String, promise: Promise) in
            guard #available(iOS 16.2, *) else { promise.resolve(nil); return }
            Task {
                await LiveActivityController.end(id: id)
                promise.resolve(nil)
            }
        }

        AsyncFunction("endAll") { (promise: Promise) in
            guard #available(iOS 16.2, *) else { promise.resolve(nil); return }
            Task {
                await LiveActivityController.endAll()
                promise.resolve(nil)
            }
        }

        // Full state of running activities, for launch reconciliation (adopt a
        // Live Activity that survived an app kill).
        AsyncFunction("getActiveSessions") { () -> [[String: Any]] in
            guard #available(iOS 16.2, *) else { return [] }
            return LiveActivityController.activeSessions()
        }
    }
}

/// Typed arguments crossing the bridge. Dates arrive as epoch seconds and are
/// converted to `Date` at the boundary.
struct StartOptions: Record {
    @Field var id: String
    @Field var name: String
    @Field var startAnchor: Double
    @Field var goalSeconds: Double?
}

struct UpdateOptions: Record {
    @Field var id: String
    @Field var isPaused: Bool
    @Field var startAnchor: Double
    @Field var pausedElapsed: Double
}

final class LiveActivityUnavailableException: Exception, @unchecked Sendable {
    override var reason: String {
        "Live Activities require iOS 16.2 or later."
    }
}

final class LiveActivitiesDisabledException: Exception, @unchecked Sendable {
    override var reason: String {
        "Live Activities are disabled. Enable them in Settings."
    }
}

@available(iOS 16.2, *)
enum LiveActivityController {
    private static let log = Logger(subsystem: "com.ejf89.livetimer", category: "LiveActivity")

    static var areEnabled: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    /// Starts a Live Activity, first ending any existing one so there is only ever
    /// a single activity (no zombies). Returns the new activity's id.
    static func start(_ options: StartOptions) async throws -> String {
        guard areEnabled else { throw LiveActivitiesDisabledException() }
        await endAll()

        let attributes = StudyAttributes(
            sessionId: options.id,
            sessionName: options.name,
            goalSeconds: options.goalSeconds
        )
        let state = StudyAttributes.ContentState(
            startAnchor: Date(timeIntervalSince1970: options.startAnchor),
            isPaused: false,
            pausedElapsed: 0
        )
        // `request` is synchronous + throwing; updates/ends are async.
        // pushType nil = local updates only (no APNs). staleDate marks the activity
        // stale if a session is left running and forgotten (8h out).
        let activity = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: Date().addingTimeInterval(8 * 3600)),
            pushType: nil
        )
        log.info("start id=\(activity.id, privacy: .public) name=\(options.name, privacy: .public)")
        return activity.id
    }

    static func update(_ options: UpdateOptions) async {
        guard let activity = activity(for: options.id) else { return }
        let state = StudyAttributes.ContentState(
            startAnchor: Date(timeIntervalSince1970: options.startAnchor),
            isPaused: options.isPaused,
            pausedElapsed: options.pausedElapsed
        )
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }

    static func end(id: String) async {
        guard let activity = activity(for: id) else { return }
        await activity.end(nil, dismissalPolicy: .immediate)
        log.info("end id=\(id, privacy: .public)")
    }

    static func endAll() async {
        let activities = Activity<StudyAttributes>.activities
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        if !activities.isEmpty {
            log.info("endAll cleared=\(activities.count)")
        }
    }

    static func activeSessions() -> [[String: Any]] {
        Activity<StudyAttributes>.activities.map { activity in
            let state = activity.content.state
            return [
                "id": activity.id,
                "name": activity.attributes.sessionName,
                "goalSeconds": activity.attributes.goalSeconds as Any,
                "startAnchor": state.startAnchor.timeIntervalSince1970,
                "isPaused": state.isPaused,
                "pausedElapsed": state.pausedElapsed,
            ]
        }
    }

    private static func activity(for id: String) -> Activity<StudyAttributes>? {
        Activity<StudyAttributes>.activities.first { $0.id == id }
    }
}
