import { StatusBar } from 'expo-status-bar';
import { useCallback, useEffect, useRef, useState } from 'react';
import {
  Alert,
  Linking,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';

import { StudyTimer } from './modules/study-timer';

const DEFAULT_GOAL_SECONDS = 1500; // 25:00

export default function App() {
  const [name, setName] = useState('Chapter 5 Review');
  const [activityId, setActivityId] = useState<string | null>(null);
  const [enabled, setEnabled] = useState(true);

  // Refs let the URL handler (registered once) read the latest values.
  const nameRef = useRef(name);
  nameRef.current = name;
  const activityIdRef = useRef(activityId);
  activityIdRef.current = activityId;

  useEffect(() => {
    setEnabled(StudyTimer.areEnabled());
  }, []);

  const running = activityId !== null;

  const startSession = useCallback(async (nameOverride?: string) => {
    const sessionName = (nameOverride ?? nameRef.current).trim() || 'Study Session';
    try {
      const sessionId = `session-${Date.now()}`;
      // start() returns the ActivityKit-assigned activity id — that's what
      // update()/end() match on, so track it (not our session id).
      const activityKitId = await StudyTimer.start({
        id: sessionId,
        name: sessionName,
        startAnchor: Date.now() / 1000, // epoch seconds
        goalSeconds: DEFAULT_GOAL_SECONDS,
      });
      if (nameOverride) setName(sessionName);
      setActivityId(activityKitId);
    } catch (e) {
      Alert.alert('Could not start', String(e));
    }
  }, []);

  const stopSession = useCallback(async () => {
    const id = activityIdRef.current;
    if (!id) return;
    await StudyTimer.end(id);
    setActivityId(null);
  }, []);

  // URL control for testing/deep-linking: livetimer://start?name=... and livetimer://stop
  useEffect(() => {
    function handleUrl(url: string | null) {
      if (!url) return;
      const match = url.match(/^livetimer:\/\/([^?]+)(?:\?(.*))?$/);
      if (!match) return;
      const [, action, query] = match;
      if (action === 'start') {
        const nameParam = (query ?? '')
          .split('&')
          .map((kv) => kv.split('='))
          .find(([k]) => k === 'name')?.[1];
        startSession(nameParam ? decodeURIComponent(nameParam) : undefined);
      } else if (action === 'stop') {
        stopSession();
      }
    }
    const sub = Linking.addEventListener('url', ({ url }) => handleUrl(url));
    Linking.getInitialURL().then(handleUrl);
    return () => sub.remove();
  }, [startSession, stopSession]);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Study Timer</Text>

      {!enabled && (
        <Text style={styles.warning}>
          Live Activities are disabled. Enable them in Settings.
        </Text>
      )}

      <TextInput
        style={styles.input}
        value={name}
        onChangeText={setName}
        placeholder="Session name"
        editable={!running}
      />

      <Text style={styles.status}>
        {running ? 'Live Activity running' : 'No active session'}
      </Text>

      {running ? (
        <Pressable style={[styles.button, styles.stop]} onPress={() => stopSession()}>
          <Text style={styles.buttonText}>Stop</Text>
        </Pressable>
      ) : (
        <Pressable style={[styles.button, styles.start]} onPress={() => startSession()}>
          <Text style={styles.buttonText}>Start New Session</Text>
        </Pressable>
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
  title: { fontSize: 28, fontWeight: '700' },
  warning: { color: '#b00020', textAlign: 'center' },
  input: {
    width: '100%',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 10,
    paddingHorizontal: 14,
    paddingVertical: 12,
    fontSize: 16,
  },
  status: { color: '#666', fontSize: 15 },
  button: {
    width: '100%',
    paddingVertical: 16,
    borderRadius: 12,
    alignItems: 'center',
  },
  start: { backgroundColor: '#0a84ff' },
  stop: { backgroundColor: '#ff3b30' },
  buttonText: { color: '#fff', fontSize: 17, fontWeight: '600' },
});
