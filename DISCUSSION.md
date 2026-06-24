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
- _(none substantive yet)_

## What would break at scale / what I'd improve
- Local updates only; server-driven updates would need ActivityKit **push tokens + APNs**.
- Two synced `StudyAttributes` copies — a shared local Swift package would remove the duplication.
