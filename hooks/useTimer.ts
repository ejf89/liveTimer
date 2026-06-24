import { useCallback, useEffect, useRef, useState } from 'react';
import { AppState } from 'react-native';

import { anchorForResume, elapsedAtPause, elapsedWhileRunning } from '../lib/timer';
import { StudyTimer } from '../modules/study-timer';

const nowSec = () => Date.now() / 1000;

export type TimerStatus = 'idle' | 'running' | 'paused';

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
  const [name, setName] = useState('Chapter 5 Review');
  const [goalSeconds, setGoalSeconds] = useState(DEFAULT_GOAL_SECONDS);
  const [debug, setDebug] = useState({ activeCount: 0, lastAction: 'idle' });

  const activityIdRef = useRef<string | null>(null);
  const startAnchorRef = useRef(0); // epoch seconds, valid while running
  const pausedElapsedRef = useRef(0); // frozen elapsed while paused

  const refreshActiveCount = useCallback(async (lastAction: string) => {
    const ids = await StudyTimer.getActiveIds();
    setDebug({ activeCount: ids.length, lastAction });
  }, []);

  // In-app display tick (local only — does not touch the Live Activity).
  useEffect(() => {
    if (status !== 'running') return;
    const handle = setInterval(() => {
      setElapsed(elapsedWhileRunning(startAnchorRef.current, nowSec()));
    }, 250);
    return () => clearInterval(handle);
  }, [status]);

  // Reconcile local state against the live truth in ActivityKit. Runs on mount (a
  // Live Activity survives an app kill, so we adopt a still-running one) and again
  // whenever the app returns to the foreground — that's when interactive controls
  // (Pause/Resume/Stop) tapped on the lock screen get mirrored back into the app:
  // the App Intent mutated the activity in Swift while we were backgrounded, so on
  // return we re-read it. No activity → it was Stopped from the Live Activity → idle.
  const reconcile = useCallback(
    async (reason: string) => {
      const sessions = await StudyTimer.getActiveSessions();
      if (sessions.length === 0) {
        activityIdRef.current = null;
        pausedElapsedRef.current = 0;
        setStatus('idle');
        setElapsed(0);
        refreshActiveCount(reason);
        return;
      }
      const [adopt, ...extras] = sessions;
      for (const extra of extras) await StudyTimer.end(extra.id);

      activityIdRef.current = adopt.id;
      startAnchorRef.current = adopt.startAnchor;
      pausedElapsedRef.current = adopt.pausedElapsed;
      setName(adopt.name);
      setGoalSeconds(adopt.goalSeconds ?? DEFAULT_GOAL_SECONDS);
      setElapsed(
        adopt.isPaused
          ? adopt.pausedElapsed
          : elapsedWhileRunning(adopt.startAnchor, nowSec()),
      );
      setStatus(adopt.isPaused ? 'paused' : 'running');
      refreshActiveCount(reason);
    },
    [refreshActiveCount],
  );

  useEffect(() => {
    // Wrapped in an async IIFE so the post-fetch setState in reconcile() isn't read as
    // a synchronous effect-body update (it only runs after getActiveSessions resolves).
    void (async () => {
      await reconcile('launch');
    })();
    const sub = AppState.addEventListener('change', (next) => {
      if (next === 'active') reconcile('foreground');
    });
    return () => sub.remove();
  }, [reconcile]);

  const start = useCallback(
    async (sessionName: string, goal = DEFAULT_GOAL_SECONDS) => {
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
      refreshActiveCount('start');
    },
    [refreshActiveCount],
  );

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
    refreshActiveCount('pause');
  }, [status, refreshActiveCount]);

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
    refreshActiveCount('resume');
  }, [status, refreshActiveCount]);

  const stop = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id) return;
    activityIdRef.current = null;
    setStatus('idle');
    setElapsed(0);
    await StudyTimer.end(id);
    refreshActiveCount('stop');
  }, [refreshActiveCount]);

  return {
    status,
    elapsed,
    name,
    setName,
    goalSeconds,
    debug,
    start,
    pause,
    resume,
    stop,
  };
}
