# Live Timer — Build Plan & Progress Tracker

> **Living document.** Update the checkboxes and "Current status" as work proceeds.
> Intended to be shareable so any agent/human can pick up the work cold.

## What we're building

A React Native / Expo iOS **study timer** that drives a native iOS **Live Activity**
(lock screen + Dynamic Island) via a hand-written native bridge. This is a job-application
challenge — see `challenge/live-activities-challenge.md` for the full spec.

The point of the exercise: demonstrate **clean bridging of React Native into a deep iOS
platform feature** (ActivityKit), plus a thoughtful writeup.

- **Repo:** `git@github.com:ejf89/liveTimer.git` (remote `origin`, branch `main`)
- **Bundle id:** `com.ejf89.livetimer` · **App Group:** `group.com.ejf89.livetimer`
- **Working dir:** `/Users/ericfarber/Development/boldvoice`

## Key decisions

> Canonical engineering invariants & conventions live in **`CLAUDE.md`** (on-device ticking,
> pause/resume `startAnchor` math, two synced `StudyAttributes` copies, no-zombie rule,
> app-killed = persists + reconcile, goal ring with linear-bar fallback). This plan tracks
> **status and milestones** and references those invariants rather than restating them, so
> the two docs can't drift. Read `CLAUDE.md` before touching native code.

Plan-level choices (not in CLAUDE.md):
- **Scope discipline:** nail Must-Haves (M1–M6) cleanly; stretch is optional, only if on track.
  Goal is to showcase planning + execution, not gold-plating.
- **`StudyAttributes` placement:** currently in `targets/widget/_shared/` (M1). In M2, once the
  module copy exists, move it to widget-only membership so there are exactly **two** copies
  (widget + module), unless app-target Swift ends up importing it (e.g. App Intents stretch).

## Architecture

```
 React Native (TypeScript)                 Native iOS
┌──────────────────────────┐    bridge    ┌───────────────────────────────┐
│ App.tsx / useTimer hook   │ ───────────► │ Expo Module: StudyTimer (Swift)│
│  • session name, goal     │  typed TS    │  Activity.request/update/end   │
│  • start/pause/resume/stop│  API         │  + launch reconciliation       │
└──────────────────────────┘ ◄─────────── └──────────────┬────────────────┘
                                                          │ shares ActivityAttributes
                                            ┌─────────────▼────────────────┐
                                            │ Widget Extension (SwiftUI)     │
                                            │  • Lock screen Live Activity   │
                                            │  • Dynamic Island ×3 views     │
                                            │  • Text(timerInterval:) ticking│
                                            └────────────────────────────────┘
```

**Planned bridge API (TS surface):**
```ts
StudyTimer.areEnabled(): boolean
StudyTimer.start({ id, name, startAnchor, goalSeconds }): Promise<string>
StudyTimer.update({ id, isPaused, startAnchor, pausedElapsed }): Promise<void>
StudyTimer.end({ id }): Promise<void>
StudyTimer.endAll(): Promise<void>          // zombie cleanup
StudyTimer.getActiveIds(): Promise<string[]>
```

## Milestones / To-dos

### M1 — Scaffold + prove widget target builds  ✅ DONE
- [x] Confirm env (Xcode 26.2, iOS 26.2 + 17.4 sims, Node 24, CocoaPods 1.16.2)
- [x] Boot iPhone 17 Pro simulator (udid `84EAE5C7-6FE5-4B08-835A-C63FA69F5078`)
- [x] Scaffold Expo TS app at repo root; wire git remote + `main` branch
- [x] Install `@bacons/apple-targets`; configure `app.json` (App Group, NSSupportsLiveActivities, plugin)
- [x] Create widget target files (`expo-target.config.js`, `_shared/StudyAttributes.swift`,
      `StudyWidgetBundle.swift`, `StudyLiveActivity.swift` — minimal)
- [x] `npx expo prebuild -p ios --clean` → `StudyWidget.appex` target present & linked
- [x] Build app + extension on simulator (`expo run:ios`) — **exit 0**
- [x] Verify app launches on simulator + screenshot
- [x] Commit M1 ("scaffold + widget target builds") — `c166231`

### M2 — Vertical slice: start/stop Live Activity  ✅ DONE
- [x] Create local Expo module `modules/study-timer` (`create-expo-module --local`); deleted template scaffolding
- [x] Copy `StudyAttributes.swift` into `modules/study-timer/ios/` (KEEP IN SYNC header)
- [x] Move `_shared/StudyAttributes.swift` → widget-only membership (two copies, not three — CLAUDE.md inv.3)
- [x] Add `index.android.ts` + `index.web.ts` no-op stubs
- [x] Implement full bridge in `StudyTimerModule.swift` (areEnabled/start/update/end/endAll/getActiveIds, @available 16.2, Promise+Task pattern)
- [x] Typed TS API (`index.ts` + `src/StudyTimer.types.ts`)
- [x] RN Start/Stop buttons + URL control (`livetimer://start|stop`) → Live Activity appears / disappears
- [x] Verified on sim (idb): lock-screen banner + Dynamic Island compact, on-device ticking, Stop clears it
- [x] Tooling: installed idb (companion + fb-idb venv) for autonomous UI taps
- [x] Commit M2

**M2 notes / carryover:**
- Lock-screen timer rendered `2:--` (width quirk in placeholder layout) → fix with proper
  HH:MM:SS + progress-bar layout in M3/M4.
- idb usage: companion `/opt/homebrew/bin/idb_companion`; CLI at
  `scratchpad/idbvenv/bin/idb`; tap by accessibility frame via `idb ui describe-all`.
- Custom-scheme `openurl` shows an "Open in app?" prompt (needs a tap); use idb taps for automation.

### M3 — Real-time ticking + pause/resume display
- [ ] `Text(timerInterval:)` on-device ticking
- [ ] Pause freezes time + shows "Paused"; resume continues; `update()` wired
- [ ] HH:MM:SS in RN UI; useTimer hook
- [ ] Screenshot (running + paused); commit

### M4 — Dynamic Island + progress ring
- [ ] Compact (name truncated + time), expanded (full name + time + progress ring), minimal (elapsed)
- [ ] Lock-screen progress bar toward goal
- [ ] Screenshots of all three presentations; commit

### M5 — Edge cases
- [ ] App-killed = **persists + keeps ticking** (decided, CLAUDE.md); reconcile on relaunch (end orphans not matching a restored session)
- [ ] Single-activity invariant (serialize on main actor; await end before next start — kill zombies on rapid start/stop)
- [ ] `staleDate`; immediate/ended dismissal so it leaves the lock screen promptly
- [ ] Debug panel (`getActiveIds()` count + last action) + `os_log` observability
- [ ] Run the edge-case test matrix (see below); commit

### M6 — Polish + docs + tests
- [ ] UI pass
- [ ] Lint/format setup + green: `npm run lint` (eslint + prettier) and swiftformat over `modules/` + `targets/`
- [ ] Jest unit tests for timer math (accumulated elapsed, formatHHMMSS, progress)
- [ ] `README.md` — LLM-runnable steps from clean checkout
- [ ] `DISCUSSION.md` — architecture / hardest / what AI got wrong / scale (**log missteps live, not at the end**)
- [ ] Final git history cleanup; push

### Stretch (only if M1–M6 on track)
- [ ] **Tier 1:** Interactive Live Activity controls via `LiveActivityIntent` + App Group state
      (pause/resume/stop from lock screen without opening app)
- [ ] **Tier 2:** Deep link from widget → active session; goal-reached `alertConfiguration` + haptic
- [ ] **Tier 3 (discuss only):** remote push updates (APNs) for scale; session history

## Testing strategy

1. **Pure logic → Jest** (no simulator): timer math, formatting, progress %.
2. **Observability:** debug panel + `os_log` (read via `xcrun simctl spawn booted log stream`).
3. **Native behavior matrix** (screenshots as evidence):

| Edge case | How to exercise | Pass criteria |
|---|---|---|
| Updates within 1–2s | start → screenshot over time | time advances |
| Pause/resume reflected | pause → screenshot | frozen time + "Paused" |
| Backgrounded keeps showing | home + lock → screenshot | still ticking |
| App killed | `simctl terminate <bundle>` | ends gracefully / persists (documented) |
| Rapid start/stop | loop start/stop ×N → `getActiveIds()` | count → 0, no zombies |
| Relaunch reconciliation | kill → relaunch | orphans ended / session restored |

## How to run (current state)

```bash
# from repo root
npx expo prebuild -p ios --clean        # regenerate ios/ (after config/target changes)
npx expo run:ios --device "84EAE5C7-6FE5-4B08-835A-C63FA69F5078"   # build + install on booted iPhone 17 Pro
```

Useful sim commands:
```bash
xcrun simctl list devices booted
xcrun simctl io booted screenshot /tmp/shot.png
xcrun simctl terminate booted com.ejf89.livetimer
xcrun simctl spawn booted log stream --predicate 'process == "StudyWidget"'
```

## Current status

**M1 + M2 DONE.** Full vertical slice works on the iPhone 17 Pro sim: Start shows the Live
Activity (lock-screen banner + Dynamic Island compact, ticking on-device while backgrounded),
Stop removes it. Hand-written Expo module bridge + typed TS API in place; idb set up for
autonomous UI testing; one real id-handling bug caught + fixed (logged in DISCUSSION.md).
**Next:** M3 — `useTimer` hook + in-app HH:MM:SS display + Pause/Resume wired to `update()`
(freeze on pause, resume continues), and fix the lock-screen time layout (`2:--` quirk).
