/** Format a number of seconds as HH:MM:SS (hours zero-padded to 2). */
export function formatHHMMSS(totalSeconds: number): string {
  const s = Math.max(0, Math.floor(totalSeconds));
  const hh = Math.floor(s / 3600);
  const mm = Math.floor((s % 3600) / 60);
  const ss = s % 60;
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${pad(hh)}:${pad(mm)}:${pad(ss)}`;
}

/** Fraction [0,1] of elapsed toward a goal (0 when no/zero goal). */
export function goalProgress(elapsedSeconds: number, goalSeconds?: number): number {
  if (!goalSeconds || goalSeconds <= 0) return 0;
  return Math.min(1, Math.max(0, elapsedSeconds / goalSeconds));
}
