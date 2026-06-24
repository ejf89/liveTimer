import { useCallback, useEffect, useRef, useState } from 'react';

import { StudyTimer } from '../modules/study-timer';

export type TimerStatus = 'idle' | 'running' | 'paused';

export const DEFAULT_GOAL_SECONDS = 1500; // 25:00

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

  const activityIdRef = useRef<string | null>(null);
  const startAnchorRef = useRef(0); // epoch seconds, valid while running
  const pausedElapsedRef = useRef(0); // frozen elapsed while paused

  // In-app display tick (local only — does not touch the Live Activity).
  useEffect(() => {
    if (status !== 'running') return;
    const handle = setInterval(() => {
      setElapsed(Date.now() / 1000 - startAnchorRef.current);
    }, 250);
    return () => clearInterval(handle);
  }, [status]);

  const start = useCallback(async (sessionName: string, goal = DEFAULT_GOAL_SECONDS) => {
    const startAnchor = Date.now() / 1000;
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
  }, []);

  const pause = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id || status !== 'running') return;
    const pausedElapsed = Date.now() / 1000 - startAnchorRef.current;
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
    const startAnchor = Date.now() / 1000 - pausedElapsedRef.current;
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

  return { status, elapsed, name, setName, goalSeconds, start, pause, resume, stop };
}
