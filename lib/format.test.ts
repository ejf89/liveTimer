import { formatHHMMSS, goalProgress } from './format';

describe('formatHHMMSS', () => {
  it('zero-pads to HH:MM:SS', () => {
    expect(formatHHMMSS(0)).toBe('00:00:00');
    expect(formatHHMMSS(5)).toBe('00:00:05');
    expect(formatHHMMSS(65)).toBe('00:01:05');
    expect(formatHHMMSS(3600)).toBe('01:00:00');
    expect(formatHHMMSS(3661)).toBe('01:01:01');
  });

  it('floors fractional seconds and clamps negatives to zero', () => {
    expect(formatHHMMSS(9.9)).toBe('00:00:09');
    expect(formatHHMMSS(-10)).toBe('00:00:00');
  });
});

describe('goalProgress', () => {
  it('returns a [0,1] fraction toward the goal', () => {
    expect(goalProgress(0, 300)).toBe(0);
    expect(goalProgress(150, 300)).toBe(0.5);
    expect(goalProgress(300, 300)).toBe(1);
  });

  it('clamps past the goal and handles missing/zero goals', () => {
    expect(goalProgress(600, 300)).toBe(1);
    expect(goalProgress(100, undefined)).toBe(0);
    expect(goalProgress(100, 0)).toBe(0);
  });
});
