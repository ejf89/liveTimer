# Fullstack Challenge: Study Timer with Live Activities

## Overview

Build a React Native/Expo iOS study timer app that displays a **Live Activity** on the iOS lock screen and **Dynamic Island**. The React Native app controls the timer; the native iOS Live Activity reflects its state in real-time.

This challenge tests your ability to bridge React Native with deep iOS platform features—something that requires navigating both ecosystems and connecting them cleanly.

## Time Expectation

**2-3 hours** with AI tools (Claude Code, Cursor, etc.) encouraged.

## The App

A simple study/focus timer with native iOS integration:

```
┌─────────────────────────────────┐
│                                 │
│      Chapter 5 Review           │
│                                 │
│         01:23:45                │
│      ━━━━━━━━━━━━━━━━━━        │
│                                 │
│   [ Pause ]    [ Stop ]         │
│                                 │
│      ─────────────────          │
│      Start New Session          │
│                                 │
└─────────────────────────────────┘
```

When running, a Live Activity appears on the lock screen:

```
┌─────────────────────────────────┐
│ 📚 Chapter 5 Review    01:23:45 │
│ ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━ │
└─────────────────────────────────┘
```

## Requirements

### Must Have

1. **React Native Timer UI**
   - Start a new session with a custom name
   - Display elapsed time (HH:MM:SS format)
   - Pause / Resume functionality
   - Stop session (ends timer and Live Activity)

2. **Live Activity (Lock Screen)**
   - Appears when timer starts
   - Shows: session name, elapsed time
   - Updates in real-time (within 1-2 seconds)
   - Disappears when timer stops
   - Reflects pause/resume state

3. **Native Bridge**
   - Create an Expo module OR native module to communicate with ActivityKit
   - Clean TypeScript interface for RN to call

4. **Edge Case Handling**
   - App backgrounded → Live Activity continues showing (even if updates pause)
   - App killed → Live Activity ends gracefully (or persists with last state)
   - Rapid start/stop → No zombie activities left behind

5. **Dynamic Island Support**
   - Compact view: session name (truncated) + time
   - Expanded view: full session name, time, progress ring
   - Minimal view: just elapsed time

## Technical Constraints

- **Must use React Native/Expo for iOS App**
- **Swift/SwiftUI** for the Live Activity widget code
- **TypeScript** for the React Native code
- Working in simulator is acceptable

## What to Submit

1. **Git repository** (upload to GitHub, public or private)
   - Clear setup instructions (README with steps to run locally that an LLM can even execute)

## What we'll cover in review

2. **Mobile iOS Demo** showing:
   - Starting a timer → Live Activity appears
   - Timer running → Live Activity updates
   - Pausing → state reflected
   - Stopping → Live Activity ends
   - Dynamic Island

3. **Discussion**:
   - Architecture decisions and why
   - What was hardest / what would you improve
   - What the AI got wrong that you had to fix

## Questions?

If requirements are unclear, make a reasonable assumption and document it.