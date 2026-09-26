import { PropsWithChildren, useEffect, useState } from 'react';
import { AppState, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { isAppLockEnabled, verifyPin } from '@/data/security';
import { radius, spacing, useAppTheme } from '@/lib/theme';

export function AppLockGate({ children }: PropsWithChildren) {
  const { colors: theme } = useAppTheme();
  const [ready, setReady] = useState(false);
  const [locked, setLocked] = useState(false);
  const [pin, setPin] = useState('');
  const [error, setError] = useState(false);
  useEffect(() => {
    isAppLockEnabled().then((enabled) => {
      setLocked(enabled);
      setReady(true);
    });
    const subscription = AppState.addEventListener('change', (state) => {
      if (state !== 'active')
        void isAppLockEnabled().then((enabled) => {
          if (enabled) setLocked(true);
        });
    });
    return () => subscription.remove();
  }, []);
  if (!ready)
    return (
      <View style={[styles.center, { backgroundColor: theme.canvas }]}>
        <MaterialIcons name="lock" size={28} color={theme.primary} />
      </View>
    );
  if (!locked) return <>{children}</>;
  const unlock = async () => {
    if (await verifyPin(pin)) {
      setPin('');
      setError(false);
      setLocked(false);
    } else setError(true);
  };
  return (
    <View style={[styles.lock, { backgroundColor: theme.canvas }]}>
      <View style={[styles.lockIcon, { backgroundColor: theme.primarySoft }]}>
        <MaterialIcons name="lock" size={30} color={theme.primary} />
      </View>
      <Text style={[styles.lockTitle, { color: theme.ink }]}>Welcome back</Text>
      <Text style={[styles.lockText, { color: theme.inkMuted }]}>Enter your PIN to open your private ledger.</Text>
      <TextInput
        autoFocus
        value={pin}
        onChangeText={(value) => {
          setPin(value.replace(/\D/g, '').slice(0, 6));
          setError(false);
        }}
        secureTextEntry
        keyboardType="number-pad"
        style={[
          styles.pin,
          { backgroundColor: theme.surface, borderColor: error ? theme.expense : theme.line, color: theme.ink },
        ]}
        onSubmitEditing={unlock}
      />
      <Text style={[styles.error, { color: theme.expense }]}>{error ? 'That PIN did not match.' : ' '}</Text>
      <Pressable onPress={unlock} style={[styles.unlock, { backgroundColor: theme.primary }]}>
        <Text style={styles.unlockText}>Unlock</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  lock: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: spacing.xl },
  lockIcon: {
    width: 70,
    height: 70,
    borderRadius: 35,
    justifyContent: 'center',
    alignItems: 'center',
    marginBottom: spacing.lg,
  },
  lockTitle: { fontSize: 26, fontWeight: '800' },
  lockText: { fontSize: 13, textAlign: 'center', marginTop: 7, marginBottom: spacing.lg },
  pin: {
    width: 220,
    textAlign: 'center',
    borderWidth: 1,
    borderRadius: radius.md,
    padding: 14,
    fontSize: 22,
    letterSpacing: 9,
  },
  error: { height: 19, marginTop: 4, fontSize: 12 },
  unlock: { width: 220, alignItems: 'center', borderRadius: radius.pill, padding: 13, marginTop: 5 },
  unlockText: { color: '#fff', fontWeight: '800' },
});
