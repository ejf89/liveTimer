import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';

import {
  anchorForResume,
  elapsedAtPause,
  elapsedWhileRunning,
  hasReachedGoal,
} from '../lib/timer';
import { StudyTimer } from '../modules/study-timer';

const nowSec = () => Date.now() / 1000;

export type TimerStatus = 'idle' | 'running' | 'paused' | 'completed';

export const DEFAULT_GOAL_SECONDS = 300; // 5:00

/**
 * Owns the study-timer state machine and the Live Activity lifecycle.
 *
 * Time is derived from `startAnchor` (epoch seconds = now - accumulatedElapsed),
 * never a stored ticking counter. The 250ms interval only drives the in-app
 * HH:MM:SS display; the Live Activity ticks itself on-device, so we call the
 * native `update()` only on real state changes (pause / resume), never per tick.
 */
export function useTimer() {
  const [status, setStatus] = useState<TimerStatus>('idle');
  const [elapsed, setElapsed] = useState(0); // seconds, for display
  const [name, setName] = useState('');
  const [goalSeconds, setGoalSeconds] = useState(DEFAULT_GOAL_SECONDS);

  const activityIdRef = useRef<string | null>(null);
  const startAnchorRef = useRef(0); // epoch seconds, valid while running
  const pausedElapsedRef = useRef(0); // frozen elapsed while paused

  // The goal is a finish line: when elapsed reaches it the session completes and the
  // clock stops at the goal value. We freeze the Live Activity with a single update
  // (the widget also pauses itself on-device via `pauseTime`, so a backgrounded or
  // killed app still stops exactly at the goal — see StudyLiveActivity.swift).
  const complete = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id) return;
    pausedElapsedRef.current = goalSeconds;
    setElapsed(goalSeconds);
    setStatus('completed');
    await StudyTimer.update({
      id,
      isPaused: true,
      startAnchor: startAnchorRef.current,
      pausedElapsed: goalSeconds,
    });
  }, [goalSeconds]);

  // In-app display tick (local only — does not touch the Live Activity), except for
  // the one-shot completion update when the goal is crossed.
  useEffect(() => {
    if (status !== 'running') return;
    const handle = setInterval(() => {
      const next = elapsedWhileRunning(startAnchorRef.current, nowSec());
      if (hasReachedGoal(next, goalSeconds)) {
        void complete();
        return;
      }
      setElapsed(next);
    }, 250);
    return () => clearInterval(handle);
  }, [status, goalSeconds, complete]);

  // Reconcile local state against the live truth in ActivityKit. Runs on mount (a
  // Live Activity survives an app kill, so we adopt a still-running one) and again
  // whenever the app returns to the foreground — that's when interactive controls
  // (Pause/Resume/Stop) tapped on the lock screen get mirrored back into the app:
  // the App Intent mutated the activity in Swift while we were backgrounded, so on
  // return we re-read it. No activity → it was Stopped from the Live Activity → idle.
  const reconcile = useCallback(
    async () => {
      const sessions = await StudyTimer.getActiveSessions();
      if (sessions.length === 0) {
        activityIdRef.current = null;
        pausedElapsedRef.current = 0;
        setStatus('idle');
        setElapsed(0);
        return;
      }
      const [adopt, ...extras] = sessions;
      for (const extra of extras) await StudyTimer.end(extra.id);

      const goal = adopt.goalSeconds ?? DEFAULT_GOAL_SECONDS;
      const liveElapsed = adopt.isPaused
        ? adopt.pausedElapsed
        : elapsedWhileRunning(adopt.startAnchor, nowSec());

      activityIdRef.current = adopt.id;
      startAnchorRef.current = adopt.startAnchor;
      setName(adopt.name);
      setGoalSeconds(goal);

      if (hasReachedGoal(liveElapsed, goal)) {
        // The session crossed its goal while we were away. Settle on the completed
        // state and, if the activity is still mid-run (killed before the completion
        // update landed), freeze it now so the widget shows "goal reached".
        pausedElapsedRef.current = goal;
        setElapsed(goal);
        setStatus('completed');
        if (!adopt.isPaused) {
          await StudyTimer.update({
            id: adopt.id,
            isPaused: true,
            startAnchor: adopt.startAnchor,
            pausedElapsed: goal,
          });
        }
      } else {
        pausedElapsedRef.current = adopt.pausedElapsed;
        setElapsed(liveElapsed);
        setStatus(adopt.isPaused ? 'paused' : 'running');
      }
    },
    [],
  );

  useEffect(() => {
    // Wrapped in an async IIFE so reconcile()'s setState isn't read as a synchronous
    // effect-body update — it only runs after getActiveSessions() resolves.
    void (async () => {
      await reconcile();
    })();
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'active') void reconcile();
    });
    return () => sub.remove();
  }, [reconcile]);

  const start = useCallback(
    async (sessionName: string, goal = goalSeconds) => {
      const startAnchor = nowSec();
      startAnchorRef.current = startAnchor;
      pausedElapsedRef.current = 0;
      // start() returns the ActivityKit activity id — that's what update()/end() match on.
      const activityId = await StudyTimer.start({
        id: `session-${Date.now()}`,
        name: sessionName,
        startAnchor,
        goalSeconds: goal,
      });
      activityIdRef.current = activityId;
      setName(sessionName);
      setGoalSeconds(goal);
      setElapsed(0);
      setStatus('running');
    },
    [goalSeconds],
  );

  // Pick the goal before starting. goalSeconds lives in the (immutable) activity
  // attributes, so it's only meaningful while idle — the UI only shows the picker then.
  const setGoal = useCallback((seconds: number) => {
    setGoalSeconds(seconds);
  }, []);

  const pause = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id || status !== 'running') return;
    const pausedElapsed = elapsedAtPause(startAnchorRef.current, nowSec());
    pausedElapsedRef.current = pausedElapsed;
    setElapsed(pausedElapsed);
    setStatus('paused');
    await StudyTimer.update({
      id,
      isPaused: true,
      startAnchor: startAnchorRef.current,
      pausedElapsed,
    });
  }, [status]);

  const resume = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id || status !== 'paused') return;
    // Re-anchor so the on-device timer resumes at the frozen value.
    const startAnchor = anchorForResume(pausedElapsedRef.current, nowSec());
    startAnchorRef.current = startAnchor;
    setStatus('running');
    await StudyTimer.update({
      id,
      isPaused: false,
      startAnchor,
      pausedElapsed: pausedElapsedRef.current,
    });
  }, [status]);

  const stop = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id) return;
    activityIdRef.current = null;
    setStatus('idle');
    setElapsed(0);
    await StudyTimer.end(id);
  }, []);

  return {
    status,
    elapsed,
    name,
    setName,
    goalSeconds,
    setGoal,
    start,
    pause,
    resume,
    stop,
  };
}
