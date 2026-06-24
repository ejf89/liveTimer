import type { StartOptions, StudyTimerApi, UpdateOptions } from './src/StudyTimer.types';

// Live Activities are an iOS-only feature; no-ops keep the web build working.
export const StudyTimer: StudyTimerApi = {
  areEnabled: () => false,
  start: async (_options: StartOptions) => '',
  update: async (_options: UpdateOptions) => {},
  end: async (_id: string) => {},
  endAll: async () => {},
  getActiveIds: async () => [],
  getActiveSessions: async () => [],
};

export type {
  StartOptions,
  UpdateOptions,
  ActiveSession,
  StudyTimerApi,
} from './src/StudyTimer.types';
