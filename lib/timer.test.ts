import {
  anchorForResume,
  elapsedAtPause,
  elapsedWhileRunning,
  hasReachedGoal,
} from './timer';

describe('timer math', () => {
  it('elapsed grows from the start anchor', () => {
    expect(elapsedWhileRunning(1000, 1000)).toBe(0);
    expect(elapsedWhileRunning(1000, 1042)).toBe(42);
  });

  it('pause freezes the current elapsed', () => {
    expect(elapsedAtPause(1000, 1075)).toBe(75);
  });

  it('resume re-anchors so the timer continues from the frozen value', () => {
    // resuming at t=2000 with 75s already elapsed -> anchor is 75s in the past
    expect(anchorForResume(75, 2000)).toBe(1925);
    expect(elapsedWhileRunning(anchorForResume(75, 2000), 2000)).toBe(75);
  });

  it('pause/resume round-trip excludes the paused gap', () => {
    const start = 1000;
    const pausedAt = 1030; // 30s elapsed
    const frozen = elapsedAtPause(start, pausedAt); // 30
    const resumedAt = 1100; // paused for 70s
    const newAnchor = anchorForResume(frozen, resumedAt);
    const finalAt = 1110; // ran 10 more seconds
    // total counted = 30 (before) + 10 (after) = 40, paused gap not counted
    expect(elapsedWhileRunning(newAnchor, finalAt)).toBe(40);
  });

  it('reaches the goal at or past the target, never before', () => {
    expect(hasReachedGoal(299, 300)).toBe(false);
    expect(hasReachedGoal(300, 300)).toBe(true);
    expect(hasReachedGoal(901, 300)).toBe(true);
  });

  it('treats a missing or zero goal as never-completing', () => {
    expect(hasReachedGoal(99999, 0)).toBe(false);
    expect(hasReachedGoal(99999, undefined)).toBe(false);
  });
});
