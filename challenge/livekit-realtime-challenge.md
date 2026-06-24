# Fullstack Challenge: Live Practice Room

## Overview

Build a **real-time "practice room"** where two users can join a session together. They should see each other's status, hear each other's audio, and see a synchronized countdown timer. Think of it as a minimal "study with me" or "body doubling" feature.

This challenge tests your ability to work with real-time infrastructure (i.e. LiveKit), manage distributed state, and build responsive UI that reflects live changes.

## Time Expectation

**2-3 hours** with AI tools (Claude Code, Cursor, etc.) encouraged.

## The App

### Screen 1: Lobby
```
┌─────────────────────────────────┐
│                                 │
│     Join a Practice Room        │
│                                 │
│  Room Code: [________]          │
│                                 │
│  Your Name: [________]          │
│                                 │
│     [ Join Room ]               │
│                                 │
│     ─────────────────           │
│     [ Create New Room ]         │
│                                 │
└─────────────────────────────────┘
```

### Screen 2: Practice Room
```
┌─────────────────────────────────┐
│  Room: ABCD-1234        [Leave] │
├─────────────────────────────────┤
│                                 │
│     ┌───────┐   ┌───────┐       │
│     │  You  │   │ Alice │       │
│     │  🎤✓  │   │  🎤✓  │       │
│     │ Ready │   │ Ready │       │
│     └───────┘   └───────┘       │
│                                 │
│         Shared Timer            │
│           24:59                 │
│     [ Start ] [ Reset ]         │
│                                 │
│     ━━━━━━━━━━━━━━━━━━━━        │
│     Audio: [🔊 On] [🔇 Mute]    │
│                                 │
└─────────────────────────────────┘
```

## Requirements

### Must Have

1. **Room Management**
   - Create a room (generates shareable code)
   - Join a room by code
   - See who's in the room (2 participants max is fine)
   - Leave room cleanly

2. **Real-Time Presence**
   - See other participant's name and status
   - Status options: "Joining", "Ready", "Focusing", "Taking Break"
   - Status changes reflect instantly for other participant

3. **Audio Communication**
   - Bidirectional audio between participants
   - Mute/unmute toggle
   - Visual indicator when someone is speaking (audio level)

4. **Synchronized Timer**
   - Shared countdown timer (e.g., 25:00 Pomodoro)
   - Either participant can Start / Pause / Reset
   - Timer stays in sync between both clients (within 1 second)
   - Visual indication when timer ends

5. **Connection Handling**
   - Handle participant disconnect gracefully
   - Show "reconnecting" state if connection drops
   - Clean up room state when both leave

6. **Late Joiner State**
   - If User B joins when timer is already running (e.g., at 12:34):
     - B must immediately see the current timer value (~12:34, not 25:00)
     - B must see A's current status (not default)
   - This must work without A doing anything—no "sync" button

## Technical Requirements

### Stack
- **Frontend:** React or React Native
- **Real-time:** LiveKit
- **Backend:** Node.js/Express, Next.js API routes, or whatever works
- **State:** However you prefer (React state, Zustand, Redux, etc.)

### LiveKit Resources
If using LiveKit (recommended):
- Free tier: https://livekit.io/pricing (no credit card required)
- React SDK: `@livekit/components-react` or `@livekit/react-native`
- Docs: https://docs.livekit.io

## What to Submit

1. **Git repository** (Upload to Github, public or private):
   - Frontend code
   - Backend code (if separate)
   - Clear setup instructions (README with steps to run locally that an LLM can even execute)

## What we'll cover in review

2. **Mobile or Web Demo** showing:
   - Create room on Client A
   - Join room on Client B (use two browser windows or devices)
   - See each other's presence
   - Audio working both directions
   - Timer sync (start on A, see on B)
   - **Late joiner use case:** A starts timer, waits 10+ seconds, then B joins—B should see current timer value immediately
   - One user disconnects, other sees it

3. **Discussion:**
   - Architecture decisions
   - How you solved timer sync
   - What would break at scale / what you'd improve

## Questions?

If requirements are unclear, make a reasonable assumption and document it.