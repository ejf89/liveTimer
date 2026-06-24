import { requireNativeModule } from 'expo';

import type { StudyTimerApi } from './src/StudyTimer.types';

// The native (iOS) implementation. Metro resolves index.android.ts / index.web.ts
// on those platforms instead, so this requireNativeModule only runs on iOS.
export const StudyTimer = requireNativeModule<StudyTimerApi>('StudyTimer');

export type {
  StartOptions,
  UpdateOptions,
  ActiveSession,
  StudyTimerApi,
} from './src/StudyTimer.types';
