import { StatusBar } from 'expo-status-bar';
import { useCallback, useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';

import { useTimer } from './hooks/useTimer';
import { useUrlControl } from './hooks/useUrlControl';
import { formatHHMMSS, goalProgress } from './lib/format';
import { StudyTimer } from './modules/study-timer';

// Study-sprint presets the goal picker offers. 30s is a quick way to demo the
// timer hitting its goal; the rest are real focus sprints (5m / 25m pomodoro / 50m).
const GOAL_PRESETS = [
  { label: '30s', seconds: 30 },
  { label: '5m', seconds: 300 },
  { label: '25m', seconds: 1500 },
  { label: '50m', seconds: 3000 },
];

export default function App() {
  const {
    status,
    elapsed,
    name,
    setName,
    goalSeconds,
    setGoal,
    start,
    pause,
    resume,
    stop,
  } = useTimer();
  // areEnabled() is a synchronous native getter, so read it once at first render.
  const [enabled] = useState(() => StudyTimer.areEnabled());

  const idle = status === 'idle';
  const paused = status === 'paused';
  const completed = status === 'completed';
  const progress = goalProgress(elapsed, goalSeconds);

  const startSession = useCallback(
    async (nameOverride?: string) => {
      const sessionName = (nameOverride ?? name).trim() || 'Study Session';
      try {
        await start(sessionName);
      } catch (e) {
        Alert.alert('Could not start', String(e));
      }
    },
    [name, start],
  );

  useUrlControl({ start: startSession, stop, pause, resume });

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Study Timer</Text>

      {!enabled && (
        <Text style={styles.warning}>
          Live Activities are disabled. Enable them in Settings.
        </Text>
      )}

      {idle ? (
        <TextInput
          style={styles.input}
          value={name}
          onChangeText={setName}
          placeholder="Name your study session"
        />
      ) : (
        <Text style={styles.sessionName}>{name}</Text>
      )}

      <Text style={styles.time}>{formatHHMMSS(elapsed)}</Text>

      <View style={styles.track}>
        <View
          style={[
            styles.fill,
            completed && styles.fillDone,
            { width: `${progress * 100}%` },
          ]}
        />
      </View>
      {idle ? (
        <View style={styles.presets}>
          {GOAL_PRESETS.map((preset) => {
            const active = goalSeconds === preset.seconds;
            return (
              <Pressable
                key={preset.seconds}
                style={[styles.chip, active && styles.chipActive]}
                onPress={() => setGoal(preset.seconds)}
              >
                <Text style={[styles.chipText, active && styles.chipTextActive]}>
                  {preset.label}
                </Text>
              </Pressable>
            );
          })}
        </View>
      ) : (
        <Text style={[styles.goalLabel, completed && styles.goalLabelDone]}>
          {completed
            ? '🎉 Goal reached'
            : paused
              ? 'Paused'
              : `Goal ${formatHHMMSS(goalSeconds)}`}
        </Text>
      )}

      {idle ? (
        <Pressable style={[styles.button, styles.start]} onPress={() => startSession()}>
          <Text style={styles.buttonText}>Start New Session</Text>
        </Pressable>
      ) : completed ? (
        <Pressable style={[styles.button, styles.done]} onPress={stop}>
          <Text style={styles.buttonText}>Done</Text>
        </Pressable>
      ) : (
        <View style={styles.row}>
          {paused ? (
            <Pressable
              style={[styles.button, styles.flex, styles.start]}
              onPress={resume}
            >
              <Text style={styles.buttonText}>Resume</Text>
            </Pressable>
          ) : (
            <Pressable style={[styles.button, styles.flex, styles.pause]} onPress={pause}>
              <Text style={styles.buttonText}>Pause</Text>
            </Pressable>
          )}
          <Pressable style={[styles.button, styles.flex, styles.stop]} onPress={stop}>
            <Text style={styles.buttonText}>Stop</Text>
          </Pressable>
        </View>
      )}

      <StatusBar style="auto" />
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#fff',
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 32,
    gap: 16,
  },
  title: { fontSize: 22, fontWeight: '600', color: '#666' },
  warning: { color: '#b00020', textAlign: 'center' },
  sessionName: { fontSize: 22, fontWeight: '700' },
  input: {
    width: '100%',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
    textAlign: 'center',
  },
  time: {
    fontSize: 64,
    fontWeight: '200',
    fontVariant: ['tabular-nums'],
    letterSpacing: 1,
  },
  track: {
    width: '100%',
    height: 6,
    borderRadius: 3,
    backgroundColor: '#eee',
    overflow: 'hidden',
  },
  fill: { height: '100%', backgroundColor: '#0a84ff', borderRadius: 3 },
  fillDone: { backgroundColor: '#34c759' },
  goalLabel: { color: '#888', fontSize: 14 },
  goalLabelDone: { color: '#34c759', fontWeight: '600' },
  presets: { flexDirection: 'row', gap: 8, justifyContent: 'center' },
  chip: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 999,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  chipActive: { backgroundColor: '#0a84ff', borderColor: '#0a84ff' },
  chipText: { color: '#555', fontSize: 15, fontWeight: '600' },
  chipTextActive: { color: '#fff' },
  row: { flexDirection: 'row', gap: 12, width: '100%' },
  flex: { flex: 1 },
  button: { paddingVertical: 16, borderRadius: 12, alignItems: 'center', width: '100%' },
  start: { backgroundColor: '#0a84ff' },
  pause: { backgroundColor: '#ff9500' },
  stop: { backgroundColor: '#ff3b30' },
  done: { backgroundColor: '#34c759' },
  buttonText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
