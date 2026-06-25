@AGENTS.md

CLAUDE.md

Study/focus timer for iOS (React Native + Expo) that drives a native Live Activity on the
lock screen and Dynamic Island. RN owns the timer; the Swift/SwiftUI widget reflects its state.

Repo: git@github.com:ejf89/liveTimer.git (origin/main) · Working dir: /Users/ericfarber/Development/boldvoice
Bundle id: com.ejf89.livetimer · App Group: group.com.ejf89.livetimer

Stack

App UI: Expo (dev client, not Expo Go) + React Native + TypeScript
Bridge: a local Expo Module (Expo Modules API, Swift) — hand-written, not a prebuilt package
Widget: Swift/SwiftUI Widget Extension target generated via @bacons/apple-targets
iOS floor: 16.2+ (Live Activities API). All ActivityKit call sites are @available(iOS 16.2, \*).

We do not use the prebuilt expo-live-activity package. The point of this project is the
bridge; building it ourselves is the deliverable. Don't swap it in.

The App Group is wired for the stretch interactive-intent work (pausing from the lock screen).
The core start/update/end path does not need it — don't make core logic depend on it.

Commands

bashnpx expo prebuild -p ios --clean # regenerate ios/ after ANY native or config change
npx expo run:ios --device "84EAE5C7-6FE5-4B08-835A-C63FA69F5078" # build + install on the iPhone 17 Pro sim
npm run lint # eslint + prettier (TS)

# Swift is formatted by swiftformat over modules/ and targets/ source

# simulator helpers

xcrun simctl io booted screenshot /tmp/shot.png
xcrun simctl terminate booted com.ejf89.livetimer
xcrun simctl spawn booted log stream --predicate 'process == "StudyWidget"'

ios/ is generated output. Never hand-edit files under ios/. Edit the module/target
source + the plugin config, then re-run prebuild. Hand edits get blown away and create drift.

Layout

App.tsx RN timer screen — start/pause/resume/stop, HH:MM:SS display
hooks/useTimer.ts timer state machine + accumulated-elapsed math (unit-tested)
modules/study-timer/
index.ts typed TS API the app calls (the clean interface)
src/StudyTimer.types.ts shared TS types
index.android.ts no-op stub so JS calls don't crash on Android
ios/StudyTimerModule.swift ActivityKit: request / update / end / endAll / reconcile
ios/StudyAttributes.swift ActivityAttributes — SYNCED COPY (see invariant 3)
expo-module.config.json
targets/widget/
\_shared/StudyAttributes.swift ActivityAttributes — source of truth
StudyWidgetBundle.swift @main widget bundle
StudyLiveActivity.swift SwiftUI: lock-screen + Dynamic Island ×3 presentations
expo-target.config.js type: "widget", frameworks: [SwiftUI, ActivityKit]
Info.plist

Bridge API (TS surface)

tsStudyTimer.areEnabled(): boolean
StudyTimer.start({ id, name, startAnchor, goalSeconds }): Promise<string> // id = caller session id; returns ActivityKit activity id
StudyTimer.update({ id, isPaused, startAnchor, pausedElapsed }): Promise<void>
StudyTimer.end({ id }): Promise<void>
StudyTimer.endAll(): Promise<void> // zombie cleanup
StudyTimer.getActiveIds(): Promise<string[]>

Critical invariants — read before touching native code

These look fine in a diff and silently break the feature. Don't undo them.

Never push an update per second. The widget renders the running timer with SwiftUI's
native Text(timerInterval:), so iOS animates the seconds on-device — even backgrounded or
killed — with zero JS↔native traffic. The bridge fires update() only on real state
changes: pause, resume, name, goal. A setInterval → update() loop is wrong.
Time is derived from startAnchor, never a stored counter. ContentState carries
startAnchor (= now − accumulatedElapsed), isPaused, pausedElapsed. JS owns accumulated
time across pauses.

Running → widget ticks from startAnchor.
Pause → set pausedElapsed = now − startAnchor; widget shows frozen pausedElapsed + "Paused".
Resume → set startAnchor = now − pausedElapsed; widget resumes ticking correctly.

StudyAttributes must stay byte-identical between targets/widget/\_shared/ and
modules/study-timer/ios/. ActivityKit matches the activity by type name + Codable shape
across modules. The widget copy is the source of truth; the module copy is synced (header note
on both). Prefer exactly two copies. \_shared/ currently also gives the widget copy
app-target membership — in M2, if no app-target Swift imports StudyAttributes, move it out of
\_shared/ to plain widget membership so there are two copies, not three.
Guard the API. Every ActivityKit call site is @available(iOS 16.2, \*) with a runtime
if #available check. The Android path is the stub and resolves to no-ops.
No zombie activities. One activity at a time. On start, end any existing first. On stop,
end() the tracked id and endAll() sweeps Activity<StudyAttributes>.activities for
strays. Use an immediate/ended dismissal so it leaves the lock screen promptly. Rapid start/stop
must not orphan an activity — serialize on the main actor and await the end before the next start.
App killed → activity persists and keeps ticking. This is deliberate (native ticking makes
it free and it demos better than ending on kill). On relaunch, reconcile: end orphaned activities
that don't match a restored session. Document this in README + DISCUSSION.

Code conventions

Write each layer in its own idiom. Swift reads like a senior iOS dev wrote it (value types,
@available, Activity.request, SwiftUI view builders); TS like a senior RN dev (typed async API,
no any, discriminated unions for state). Don't transliterate one into the other.

Name for the concept, not the representation. accumulatedElapsed, startAnchor,
isPaused, goalSeconds — not data, val, t, flag, temp.
Session state is a union, not loose booleans: 'idle' | 'running' | 'paused'. UI and bridge
branch on it exhaustively.
Functions are verb-first and do one thing: startSession, pauseSession, endLiveActivity.
Comment the why of platform quirks, not the what. Explain the timerInterval choice or a
@available guard; never // loop over the array.
No dead code, no commented-out blocks, no leftover Expo-module template scaffolding. Delete
generated example files we don't use.
Run the formatters/linters before considering a change done.

Goal ring + goal-stop (documented assumption)

The spec mockup shows a progress ring on a count-up timer, which only has meaning against a target.
Each session has an optional goalSeconds, default 300 (5:00 — a focus sprint short enough that the
ring/bar visibly fills during a demo). The ring/bar fills toward the goal.

The goal is a finish line: when elapsed reaches goalSeconds the session COMPLETES and the clock
stops at the goal value (status 'completed'). This must hold even when the app is backgrounded or
killed, so the freeze is on-device — the widget's running Text uses Text(timerInterval:pauseTime:)
with pauseTime = startAnchor + goal, so iOS halts the clock at the goal with no push. JS also fires
one completion update() on crossing (never per-second) to switch the activity to its "goal reached"
presentation. Completion is DERIVED, not a new ContentState field: isPaused && pausedElapsed >= goal
(in Swift, hasReachedGoal(context)) reads as done, so the bridge/attributes contract is unchanged.
A goalSeconds of 0 / nil means no goal — the timer counts on (24h-bounded, see ElapsedText).

Verify circular ProgressView(timerInterval:) actually animates its fill natively — if it doesn't,
the lock-screen linear bar is the fallback (the mockup uses a bar anyway), so a finicky ring never
stalls the milestone.

Definition of done

A change isn't done until it builds clean on the simulator and the relevant rubric item passes by hand:

Start → Live Activity appears within ~1–2s
Running → timer advances live with no per-second pushes
Pause → frozen time + "Paused"; Resume → continues from the right value
Stop → Live Activity disappears
Backgrounded / killed → keeps ticking; relaunch reconciles
Rapid start/stop → getActiveIds() returns 0, no zombies
Dynamic Island: compact (name + time), expanded (name, time, progress ring), minimal (time)

Notes

Status/milestones live in the build-plan doc, not here. Keep invariants/conventions canonical
here; the plan references them rather than restating, so they don't drift.
Log AI missteps live as they happen — DISCUSSION.md ("what the AI got wrong") is graded, and
reconstructing it at the end is weak.

Skills

Platform-specific deep knowledge lives in .claude/skills/. Consult ios-live-activities before
writing or editing any ActivityKit / SwiftUI widget code — it carries the correct patterns for the
invariants above and the common failure modes.
