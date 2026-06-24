# Discussion

> Maintained live during the build (per CLAUDE.md). Final writeup for the review covers:
> architecture decisions, what was hardest, what the AI got wrong, and what would break at scale.

## Architecture decisions
_(to be expanded — see CLAUDE.md for canonical invariants)_

- **On-device ticking via `Text(timerInterval:)`** instead of per-second JS pushes — the
  single most important decision; see CLAUDE.md.
- **Hand-written Expo Module bridge** rather than the `expo-live-activity` package — owning the
  bridge is the deliverable.
- **`@bacons/apple-targets`** for reproducible widget-target generation across `prebuild`.

## What was hardest
_(to fill in as it happens)_

## What the AI got wrong (logged live)
- **Expo `AsyncFunction` doesn't take Swift `async throws` closures.** First pass wrote
  `AsyncFunction("start") { (o) async throws -> String in ... }`; the compiler rejected it
  ("cannot pass function of type 'async throws -> String' to parameter expecting synchronous
  function type"). Correct pattern: a synchronous closure that takes a `Promise`, spawns a
  `Task`, and resolves/rejects it. Fixed across start/update/end/endAll.
- **Swift Sendable warning:** `Exception` subclasses must restate `@unchecked Sendable`.
- **Caller session id vs ActivityKit activity id confusion.** `start()` returns the
  ActivityKit-assigned id, which `update()`/`end()` match on — but the first App.tsx stored
  the locally-generated `session-<ts>` id instead and passed that to `end()`. The lookup
  silently found nothing, so Stop updated the UI but **leaked the Live Activity** (caught via
  the Dynamic Island still ticking after Stop). Fix: track the returned activity id.
- **Tooling slip (mine, not the code):** ran the first `expo run:ios` from inside `ios/` (a
  stale `cd` persisted), so Expo resolved the wrong project root; re-ran from repo root.

## What would break at scale / what I'd improve
- Local updates only; server-driven updates would need ActivityKit **push tokens + APNs**.
- Two synced `StudyAttributes` copies — a shared local Swift package would remove the duplication.
