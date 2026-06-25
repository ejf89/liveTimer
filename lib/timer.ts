// Pure timer math. Time is derived from a `startAnchor` (epoch seconds), never a
// stored ticking counter, so the same math drives the in-app display and the
// native Live Activity. All values are in seconds.

/** Elapsed seconds for a running session anchored at `startAnchor`. */
export function elapsedWhileRunning(startAnchorSec: number, nowSec: number): number {
  return nowSec - startAnchorSec;
}

/** Frozen elapsed captured at the moment of pause. */
export function elapsedAtPause(startAnchorSec: number, nowSec: number): number {
  return nowSec - startAnchorSec;
}

/**
 * New anchor when resuming, so the timer continues from the frozen value:
 * effectiveStart = now - alreadyElapsed.
 */
export function anchorForResume(pausedElapsedSec: number, nowSec: number): number {
  return nowSec - pausedElapsedSec;
}

/**
 * Whether a session has hit its goal and should stop. A missing or non-positive
 * goal means "no goal" — the timer never auto-completes.
 */
export function hasReachedGoal(elapsedSec: number, goalSec?: number): boolean {
  return !!goalSec && goalSec > 0 && elapsedSec >= goalSec;
}
