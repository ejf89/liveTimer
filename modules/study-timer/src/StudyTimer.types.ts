// Shared types for the StudyTimer bridge. Dates cross the bridge as epoch seconds.

export type StartOptions = {
  /** Caller-owned session id; also used to locate the activity for update/end. */
  id: string;
  name: string;
  /** Effective count-up start, epoch seconds (= now - accumulatedElapsed). */
  startAnchor: number;
  /** Optional study goal in seconds; drives the progress ring/bar. */
  goalSeconds?: number;
};

export type UpdateOptions = {
  id: string;
  isPaused: boolean;
  startAnchor: number;
  /** Elapsed seconds frozen at pause, for static display. */
  pausedElapsed: number;
};

export type StudyTimerApi = {
  /** Whether Live Activities are available + enabled (false on non-iOS / < 16.2). */
  areEnabled(): boolean;
  /** Start a Live Activity; resolves with the ActivityKit activity id. */
  start(options: StartOptions): Promise<string>;
  /** Push a state change (pause/resume/anchor). Never call this on a timer tick. */
  update(options: UpdateOptions): Promise<void>;
  /** End the activity with the given id. */
  end(id: string): Promise<void>;
  /** End every live activity (zombie sweep). */
  endAll(): Promise<void>;
  /** Ids of all currently-running activities. */
  getActiveIds(): Promise<string[]>;
};
