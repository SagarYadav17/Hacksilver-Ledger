import { PropsWithChildren, useCallback, useEffect, useRef, useState } from 'react';
import { AppState, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import * as LocalAuthentication from 'expo-local-authentication';
import * as ScreenCapture from 'expo-screen-capture';
import {
  getLockoutState,
  isAppLockEnabled,
  isBiometricEnabled,
  resetFailedAttempts,
  subscribeSecurity,
  verifyPin,
} from '@/data/security';
import { radius, spacing, useAppTheme } from '@/lib/theme';

const CAPTURE_KEY = 'hacksilver.app-lock';
let authenticating = false;

export async function canUseBiometrics(): Promise<boolean> {
  try {
    return (await LocalAuthentication.hasHardwareAsync()) && (await LocalAuthentication.isEnrolledAsync());
  } catch {
    return false;
  }
}

export async function authenticateBiometric(): Promise<boolean> {
  if (authenticating) return false;
  authenticating = true;
  try {
    const result = await LocalAuthentication.authenticateAsync({
      promptMessage: 'Unlock Hacksilver',
      disableDeviceFallback: true,
      cancelLabel: 'Use PIN',
    });
    if (result.success) await resetFailedAttempts();
    return result.success;
  } catch {
    return false;
  } finally {
    authenticating = false;
  }
}

async function applyCaptureProtection(enabled: boolean) {
  if (Platform.OS === 'web') return;
  try {
    if (enabled) {
      await ScreenCapture.preventScreenCaptureAsync(CAPTURE_KEY);
      if (Platform.OS === 'ios') await ScreenCapture.enableAppSwitcherProtectionAsync();
    } else {
      await ScreenCapture.allowScreenCaptureAsync(CAPTURE_KEY);
      if (Platform.OS === 'ios') await ScreenCapture.disableAppSwitcherProtectionAsync();
    }
  } catch {}
}

function formatWait(ms: number) {
  const seconds = Math.ceil(ms / 1000);
  return `${Math.floor(seconds / 60)}:${String(seconds % 60).padStart(2, '0')}`;
}

function usePinEntry(onSuccess: () => void) {
  const [pin, setPin] = useState('');
  const [error, setError] = useState(false);
  const [busy, setBusy] = useState(false);
  const [biometric, setBiometric] = useState(false);
  const [lockedUntil, setLockedUntil] = useState(0);
  const [now, setNow] = useState(Date.now);
  const success = useRef(onSuccess);
  useEffect(() => {
    success.current = onSuccess;
  });
  const lockedOut = lockedUntil > now;
  useEffect(() => {
    void getLockoutState().then(({ lockoutUntil }) => {
      setNow(Date.now());
      setLockedUntil(lockoutUntil);
    });
    void isBiometricEnabled().then(setBiometric);
  }, []);
  useEffect(() => {
    if (!lockedOut) return;
    const timer = setInterval(() => setNow(Date.now()), 1000);
    return () => clearInterval(timer);
  }, [lockedOut]);
  const submit = async () => {
    if (busy || lockedOut || !pin) return;
    setBusy(true);
    const result = await verifyPin(pin);
    setBusy(false);
    setPin('');
    if (result.ok) {
      setError(false);
      success.current();
      return;
    }
    setError(true);
    setNow(Date.now());
    if (result.lockedUntil) setLockedUntil(result.lockedUntil);
  };
  const unlockWithBiometric = useCallback(async () => {
    if (!(await authenticateBiometric())) return;
    setLockedUntil(0);
    setError(false);
    success.current();
  }, []);
  const change = (value: string) => {
    setPin(value.replace(/\D/g, '').slice(0, 6));
    setError(false);
  };
  const message = lockedOut
    ? `Too many attempts. Try again in ${formatWait(lockedUntil - now)}.`
    : error
      ? 'That PIN did not match.'
      : ' ';
  return { pin, change, submit, busy, lockedOut, error, message, biometric, unlockWithBiometric };
}

function PinEntry({ entry, autoFocus }: { entry: ReturnType<typeof usePinEntry>; autoFocus?: boolean }) {
  const { colors: theme } = useAppTheme();
  const disabled = entry.lockedOut || entry.busy;
  return (
    <View style={styles.entry}>
      <TextInput
        autoFocus={autoFocus}
        value={entry.pin}
        onChangeText={entry.change}
        editable={!disabled}
        secureTextEntry
        keyboardType="number-pad"
        style={[
          styles.pin,
          {
            backgroundColor: theme.surface,
            borderColor: entry.error || entry.lockedOut ? theme.expense : theme.line,
            color: theme.ink,
            opacity: entry.lockedOut ? 0.5 : 1,
          },
        ]}
        onSubmitEditing={entry.submit}
      />
      <Text style={[styles.error, { color: theme.expense }]}>{entry.message}</Text>
      <Pressable
        onPress={entry.submit}
        disabled={disabled}
        style={[styles.unlock, { backgroundColor: theme.primary, opacity: disabled ? 0.5 : 1 }]}
      >
        <Text style={styles.unlockText}>Unlock</Text>
      </Pressable>
      {entry.biometric ? (
        <Pressable onPress={entry.unlockWithBiometric} style={styles.biometric}>
          <MaterialIcons name="fingerprint" size={20} color={theme.primary} />
          <Text style={[styles.biometricText, { color: theme.primary }]}>Use biometrics</Text>
        </Pressable>
      ) : null}
    </View>
  );
}

export function PinVerifyForm({
  title,
  onVerified,
  onCancel,
}: {
  title: string;
  onVerified: () => void;
  onCancel: () => void;
}) {
  const { colors: theme } = useAppTheme();
  const entry = usePinEntry(onVerified);
  return (
    <View>
      <Text style={[styles.formTitle, { color: theme.ink }]}>{title}</Text>
      <Text style={[styles.formCaption, { color: theme.inkMuted }]}>Enter your current PIN to continue.</Text>
      <PinEntry entry={entry} autoFocus />
      <Pressable onPress={onCancel} style={styles.cancel}>
        <Text style={[styles.cancelText, { color: theme.inkMuted }]}>Cancel</Text>
      </Pressable>
    </View>
  );
}

function LockScreen({ onUnlock }: { onUnlock: () => void }) {
  const { colors: theme } = useAppTheme();
  const entry = usePinEntry(onUnlock);
  const prompted = useRef(false);
  const { biometric, unlockWithBiometric } = entry;
  useEffect(() => {
    if (!biometric) return;
    const prompt = () => {
      if (prompted.current || AppState.currentState !== 'active') return;
      prompted.current = true;
      void unlockWithBiometric();
    };
    prompt();
    const subscription = AppState.addEventListener('change', (state) => {
      if (state === 'background') prompted.current = false;
      else if (state === 'active') prompt();
    });
    return () => subscription.remove();
  }, [biometric, unlockWithBiometric]);
  return (
    <View style={[styles.lock, { backgroundColor: theme.canvas }]}>
      <View style={[styles.lockIcon, { backgroundColor: theme.primarySoft }]}>
        <MaterialIcons name="lock" size={30} color={theme.primary} />
      </View>
      <Text style={[styles.lockTitle, { color: theme.ink }]}>Welcome back</Text>
      <Text style={[styles.lockText, { color: theme.inkMuted }]}>Enter your PIN to open your private ledger.</Text>
      <PinEntry entry={entry} autoFocus />
    </View>
  );
}

export function AppLockGate({ children }: PropsWithChildren) {
  const { colors: theme } = useAppTheme();
  const [ready, setReady] = useState(false);
  const [enabled, setEnabled] = useState(false);
  const [locked, setLocked] = useState(false);
  const enabledRef = useRef(false);
  useEffect(() => {
    let initial = true;
    const load = () =>
      isAppLockEnabled().then((value) => {
        enabledRef.current = value;
        setEnabled(value);
        if (!initial) return;
        initial = false;
        setLocked(value);
        setReady(true);
      });
    void load();
    const unsubscribe = subscribeSecurity(() => void load());
    const subscription = AppState.addEventListener('change', (state) => {
      if (!enabledRef.current) return;
      // 'inactive' also fires for system sheets/pickers; snapshots are covered by capture protection instead.
      if (state === 'background') setLocked(true);
    });
    return () => {
      unsubscribe();
      subscription.remove();
    };
  }, []);
  useEffect(() => {
    if (ready) void applyCaptureProtection(enabled);
  }, [ready, enabled]);
  if (!ready)
    return (
      <View style={[styles.center, { backgroundColor: theme.canvas }]}>
        <MaterialIcons name="lock" size={28} color={theme.primary} />
      </View>
    );
  // Unmount the app while locked: RN Modal/Alert render in their own native window and would sit above an overlay.
  if (locked) return <LockScreen onUnlock={() => setLocked(false)} />;
  return <>{children}</>;
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
  entry: { alignItems: 'center' },
  pin: {
    width: 220,
    textAlign: 'center',
    borderWidth: 1,
    borderRadius: radius.md,
    padding: 14,
    fontSize: 22,
    letterSpacing: 9,
  },
  error: { minHeight: 19, marginTop: 4, fontSize: 12, textAlign: 'center', maxWidth: 260 },
  unlock: { width: 220, alignItems: 'center', borderRadius: radius.pill, padding: 13, marginTop: 5 },
  unlockText: { color: '#fff', fontWeight: '800' },
  biometric: { flexDirection: 'row', alignItems: 'center', gap: 6, padding: 12, marginTop: spacing.sm },
  biometricText: { fontSize: 13, fontWeight: '800' },
  formTitle: { fontSize: 21, fontWeight: '800' },
  formCaption: { fontSize: 11, marginTop: 4, marginBottom: spacing.md },
  cancel: { alignSelf: 'flex-end', marginTop: spacing.md },
  cancelText: { fontSize: 13, fontWeight: '700' },
});
