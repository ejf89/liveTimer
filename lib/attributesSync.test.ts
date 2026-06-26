import { readFileSync } from 'fs';
import { join } from 'path';

// StudyAttributes is intentionally duplicated: ActivityKit matches an Activity to its
// widget by the attributes type name + Codable shape, and the bridge pod and widget are
// separate compilation units, so each needs its own copy (see DISCUSSION.md). The copies
// are hand-synced — this guard makes the sync enforceable instead of trusted: it strips
// comments/blank lines and asserts the two declarations are identical, so they can't drift.

const ROOT = join(__dirname, '..');
const WIDGET_COPY = join(ROOT, 'targets/widget/_shared/StudyAttributes.swift');
const MODULE_COPY = join(ROOT, 'modules/study-timer/ios/StudyAttributes.swift');

/** Strip comment-only lines and blanks, trim each line — leaving just the declaration. */
function declarationOnly(path: string): string {
  return readFileSync(path, 'utf8')
    .split('\n')
    .map((line) => line.trimEnd())
    .filter((line) => line.trim() !== '' && !line.trim().startsWith('//'))
    .join('\n');
}

describe('StudyAttributes copies stay in sync', () => {
  const widget = declarationOnly(WIDGET_COPY);
  const module = declarationOnly(MODULE_COPY);

  it('both copies actually declare the struct (guard against an empty/renamed file)', () => {
    expect(widget).toContain('struct StudyAttributes: ActivityAttributes');
    expect(widget).toContain('var startAnchor: Date');
    expect(widget).toContain('var goalSeconds: Double?');
  });

  it('the two declarations are identical (comments aside)', () => {
    // If this fails, the widget and bridge-pod copies of StudyAttributes have diverged.
    // ActivityKit will silently fail to decode the activity across the module boundary.
    expect(module).toBe(widget);
  });
});
