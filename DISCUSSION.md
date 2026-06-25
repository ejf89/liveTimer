# Discussion

A study timer (React Native / Expo) whose state is mirrored to a native iOS Live Activity on
the lock screen and Dynamic Island, with interactive controls. This covers the architecture,
what was hardest, what the AI got wrong, and what I'd change at scale. Canonical engineering
invariants live in `CLAUDE.md`.

## Architecture decisions

**The system is four compilation units, and most decisions follow from that:**

1. **JS/TS** — `App.tsx`, `hooks/`, `lib/`, and the module's `index.ts` (the typed API).
2. **Bridge pod** — `modules/study-timer/ios/` — a hand-written Expo module (CocoaPod) that
   exposes `start/update/end/endAll/getActiveIds/getActiveSessions` to JS and calls ActivityKit.
3. **App target** — the Expo app + the `_shared/` Swift (the App Intent's `perform()` runs here).
4. **Widget extension** — SwiftUI lock-screen + Dynamic Island UI; references the App Intent.

Key choices:

- **On-device ticking via `Text(timerInterval:)`** instead of pushing an update every second.
  iOS animates the seconds itself, so the timer keeps ticking while backgrounded or killed with
  **zero JS↔native traffic**. The bridge only calls `update()` on real state changes
  (pause/resume). This single decision drives the real-time, background, and battery behavior.
- **JS owns the time math via a `startAnchor`** (epoch seconds = now − accumulatedElapsed),
  never a stored counter. Pause freezes `pausedElapsed`; resume re-anchors. The same math is
  pure-tested (`lib/timer.ts`) and mirrored in Swift for the interactive intent.
- **Hand-written bridge**, not the `expo-live-activity` package — owning the bridge is the point.
- **`@bacons/apple-targets`** generates the widget target at `prebuild`, so the whole native
  project (`ios/`) is reproducible from a clean checkout (`ios/` is gitignored).
- **Interactive controls via `LiveActivityIntent` (iOS 17+)** — Pause/Resume/Stop buttons *on*
  the Live Activity. The intent lives in `_shared/` so it compiles into both the widget (to build
  `Button(intent:)`) and the app (where `perform()` runs in the background, no UI), and mutates
  the activity directly in Swift.
- **Compact Dynamic Island shows the truncated session name + time** (per the spec). The slots
  flank the camera and are narrow, so the name is width-capped and truncates; the full,
  untruncated name lives in the expanded + lock-screen views. A pause glyph + orange tint signal
  the paused state in the tight compact space.
- **Goal defaults to 5:00** (a focus sprint) so the progress ring/bar fills visibly.
- **The goal is a finish line — the timer stops when it reaches it** (status `completed`, "Goal
  reached"). The freeze had to survive backgrounding/kill, so it's done on-device: the widget's
  running clock uses `Text(timerInterval:pauseTime:)` with `pauseTime = startAnchor + goal`, so iOS
  halts it at the goal with no push; JS fires one completion `update()` on crossing (never
  per-second) to switch the activity to its "goal reached" look. Completion is *derived*
  (`isPaused && pausedElapsed >= goal`), so the `StudyAttributes` contract stayed unchanged — at the
  cost that a purely-backgrounded app shows the time freeze + full bar at the goal but only gets the
  textual "goal reached" badge once it next becomes active and pushes the update.

## What was hardest

- **Verifying a native, lock-screen feature non-interactively.** Live Activities only show
  backgrounded/locked, and the simulator blocks programmatic taps without accessibility. Solved
  by installing `idb` (tap by accessibility frame, lock/home buttons) plus a `livetimer://` URL
  control, so the whole flow — including the App-Intent buttons — is scriptable and screenshot-verifiable.
- **The `_shared` boundary for the App Intent.** The intent must exist in both the app and widget
  targets, which in turn required `StudyAttributes` to be app-target-visible — a deliberate move
  back into `_shared` (see the two-copies trade-off below).

## What the AI got wrong (logged live)

- **Expo `AsyncFunction` doesn't take Swift `async throws` closures.** First pass wrote
  `AsyncFunction("start") { (o) async throws -> String in ... }`; the compiler rejected it. The
  correct pattern is a synchronous closure that takes a `Promise`, spawns a `Task`, and
  resolves/rejects it.
- **Caller session id vs ActivityKit activity id.** `start()` returns the ActivityKit-assigned
  id (what `update()`/`end()` match on), but the first App.tsx tracked its own `session-<ts>` id
  and passed that to `end()`. The lookup silently found nothing, so Stop updated the UI but
  **leaked the Live Activity** — caught because the Dynamic Island kept ticking after Stop.
- **`Text(timerInterval: start...distantFuture)` degrades to "M:--".** An unbounded interval
  makes the text reserve width for the whole (infinite) range, so at larger fonts it drops the
  seconds. Masked at first because it only shows past one minute; fixed by bounding the interval
  to 24h. (A *narrower* sub-1h bound to tighten the compact slot backfired — it drops the leading
  digit to ":05" — so the same 24h bound is used everywhere.)
- **Interactive controls desynced the app.** Tapping Pause/Stop *on the Live Activity* runs the
  App Intent's `perform()`, which mutates the activity in Swift — but a still-running RN app
  never re-read it, so after Stopping from the lock screen the app kept showing a live timer.
  Fixed by reconciling against ActivityKit on `AppState` → `active`: returning to the app (the
  only moment you can, after touching a locked screen) re-reads the activities — none → idle,
  paused → paused. The launch-time reconciliation was refactored to serve both paths.
- **Time format jumped on pause.** The running timer renders natively as `M:SS / H:MM:SS`
  (`0:34`), but the paused state used a static `HH:MM:SS` (`00:00:34`), so pausing visibly
  reformatted. Unified the paused string to the same compact shape. The spec scopes `HH:MM:SS`
  to the **React Native UI** (§1) and leaves the Live Activity format open (§2/§5) — exactly
  because the native timer can't be padded — so the app keeps `HH:MM:SS` and the activity uses
  the native shape.
- **The minimal Dynamic Island can't be exercised on the simulator.** iOS only shows the minimal
  presentation when two Live Activities from *different apps* are active; multiple activities from
  the *same* app collapse to one compact view (verified with three concurrent activities). With no
  stock app shipping a Live Activity on the sim (no Clock app), minimal is only viewable via an
  Xcode `#Preview`. It's implemented and correct; it just isn't runtime-photographable here.
- Minor: `Exception` subclasses must restate `@unchecked Sendable`; an early `expo run:ios` ran
  from a stale `cd ios` working directory.

## What would break at scale / what I'd improve

- **Server-driven updates:** today updates are local. Driving a Live Activity from a backend
  (e.g. a shared "study room") needs ActivityKit **push tokens + APNs**; the bridge would
  register for `pushType: .token` and report the token to the server.
- **One source of truth for `StudyAttributes`:** it currently exists as two source files (the
  `_shared` copy compiled into app+widget, and the bridge-pod copy) kept in sync by hand. A local
  Swift Package depended on by the pod, app, and widget would remove the duplication entirely.
- **Goal as a first-class input** (currently a default), and **session history/stats** persisted
  across launches.
- **Home Screen / Control Center widgets** reusing the same attributes — the widget extension is
  already in place to host them.
