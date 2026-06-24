import type { StartOptions, StudyTimerApi, UpdateOptions } from './src/StudyTimer.types';

// Live Activities are an iOS-only feature. These no-ops let shared JS call the
// same API on Android without crashing (areEnabled() reports false).
export const StudyTimer: StudyTimerApi = {
  areEnabled: () => false,
  start: async (_options: StartOptions) => '',
  update: async (_options: UpdateOptions) => {},
  end: async (_id: string) => {},
  endAll: async () => {},
  getActiveIds: async () => [],
};

export type { StartOptions, UpdateOptions, StudyTimerApi } from './src/StudyTimer.types';
