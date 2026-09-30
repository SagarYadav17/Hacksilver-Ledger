import { useEffect, useState } from 'react';
import { Alert, KeyboardAvoidingView, Modal, Pressable, StyleSheet, Switch, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppStore } from '@/store/app-store';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Header, Pill, Screen } from '@/components/ui';
import {
  clearPin,
  isAppLockEnabled,
  isBiometricEnabled,
  setBiometricEnabled,
  setPin as persistPin,
} from '@/data/security';
import { authenticateBiometric, canUseBiometrics, PinVerifyForm } from '@/components/security';

type PinModal = 'create' | 'change' | 'verify-disable' | 'verify-change' | null;

export default function SettingsScreen() {
  const router = useRouter();
  const { colors: theme, dark } = useAppTheme();
  const currency = useAppStore((state) => state.currency);
  const setCurrency = useAppStore((state) => state.setCurrency);
  const hidden = useAppStore((state) => state.hideBalances);
  const setHidden = useAppStore((state) => state.setHideBalances);
  const [lock, setLock] = useState(false);
  const [biometric, setBiometric] = useState(false);
  const [biometricAvailable, setBiometricAvailable] = useState(false);
  const [pinModal, setPinModal] = useState<PinModal>(null);
  const [pin, setPin] = useState('');
  const [confirm, setConfirm] = useState('');
  useEffect(() => {
    void isAppLockEnabled().then(setLock);
    void isBiometricEnabled().then(setBiometric);
    void canUseBiometrics().then(setBiometricAvailable);
  }, []);
  const closeModal = () => {
    setPin('');
    setConfirm('');
    setPinModal(null);
  };
  const savePin = async () => {
    if (pin.length < 4 || pin !== confirm) {
      Alert.alert('Check your PIN', 'Use at least four digits and enter the same PIN twice.');
      return;
    }
    await persistPin(pin);
    closeModal();
    setLock(true);
  };
  const onVerified = async () => {
    if (pinModal === 'verify-change') {
      setPinModal('change');
      return;
    }
    await clearPin();
    closeModal();
    setLock(false);
    setBiometric(false);
  };
  const toggleLock = (value: boolean) => setPinModal(value ? 'create' : 'verify-disable');
  const toggleBiometric = async (value: boolean) => {
    if (value && !(await authenticateBiometric())) return;
    await setBiometricEnabled(value);
    setBiometric(value);
  };
  return (
    <Screen>
      <View style={styles.top}>
        <Pressable onPress={() => router.back()}>
          <MaterialIcons name="arrow-back" size={24} color={theme.ink} />
        </Pressable>
        <Header eyebrow="Preferences" title="Settings" />
        <View style={{ width: 24 }} />
      </View>
      <Text style={[styles.section, { color: theme.ink }]}>Appearance</Text>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        <Text style={[styles.label, { color: theme.ink }]}>Currency</Text>
        <View style={styles.pills}>
          {['INR', 'USD', 'EUR', 'GBP'].map((item) => (
            <Pill key={item} label={item} selected={currency === item} onPress={() => setCurrency(item)} />
          ))}
        </View>
        <View style={styles.settingRow}>
          <View style={styles.copy}>
            <Text style={[styles.label, { color: theme.ink }]}>Hide balances</Text>
            <Text style={[styles.caption, { color: theme.inkMuted }]}>Keep amounts private while you browse</Text>
          </View>
          <Switch
            value={hidden}
            onValueChange={setHidden}
            trackColor={{ false: theme.line, true: theme.primary }}
            thumbColor={theme.white}
          />
        </View>
      </View>
      <Text style={[styles.section, { color: theme.ink }]}>Security</Text>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        <View style={styles.settingRow}>
          <View style={styles.copy}>
            <Text style={[styles.label, { color: theme.ink }]}>App lock</Text>
            <Text style={[styles.caption, { color: theme.inkMuted }]}>
              {lock ? 'PIN protection is enabled' : 'Require a PIN when returning to the app'}
            </Text>
          </View>
          <Switch
            value={lock}
            onValueChange={toggleLock}
            trackColor={{ false: theme.line, true: theme.primary }}
            thumbColor={theme.white}
          />
        </View>
        {lock && biometricAvailable ? (
          <View style={styles.settingRow}>
            <View style={styles.copy}>
              <Text style={[styles.label, { color: theme.ink }]}>Use biometrics</Text>
              <Text style={[styles.caption, { color: theme.inkMuted }]}>Unlock with your face or fingerprint</Text>
            </View>
            <Switch
              value={biometric}
              onValueChange={toggleBiometric}
              trackColor={{ false: theme.line, true: theme.primary }}
              thumbColor={theme.white}
            />
          </View>
        ) : null}
        {lock ? (
          <Pressable onPress={() => setPinModal('verify-change')} style={styles.settingRow}>
            <View style={styles.copy}>
              <Text style={[styles.label, { color: theme.ink }]}>Change PIN</Text>
              <Text style={[styles.caption, { color: theme.inkMuted }]}>Confirm your current PIN first</Text>
            </View>
            <MaterialIcons name="chevron-right" size={22} color={theme.inkMuted} />
          </Pressable>
        ) : null}
      </View>
      <View style={[styles.note, { backgroundColor: dark ? theme.surfaceAlt : theme.primarySoft }]}>
        <MaterialIcons name="shield" size={19} color={theme.primary} />
        <Text style={[styles.noteText, { color: theme.ink }]}>
          Your ledger stays on this device by default. Cloud sync is always opt-in.
        </Text>
      </View>
      <Modal visible={pinModal !== null} transparent animationType="slide" onRequestClose={closeModal}>
        <KeyboardAvoidingView behavior="padding" style={styles.modalBackdrop}>
          <View style={[styles.modal, { backgroundColor: theme.surface }]}>
            {pinModal === 'verify-disable' || pinModal === 'verify-change' ? (
              <PinVerifyForm
                key={pinModal}
                title={pinModal === 'verify-disable' ? 'Turn off app lock' : 'Change PIN'}
                onVerified={onVerified}
                onCancel={closeModal}
              />
            ) : (
              <>
                <Text style={[styles.modalTitle, { color: theme.ink }]}>
                  {pinModal === 'change' ? 'Choose a new PIN' : 'Create a PIN'}
                </Text>
                <Text style={[styles.caption, { color: theme.inkMuted }]}>
                  You’ll use this whenever the app is locked.
                </Text>
                <TextInput
                  value={pin}
                  onChangeText={(value) => setPin(value.replace(/\D/g, '').slice(0, 6))}
                  secureTextEntry
                  keyboardType="number-pad"
                  placeholder="PIN"
                  placeholderTextColor={theme.inkMuted}
                  style={[styles.modalInput, { color: theme.ink, borderColor: theme.line }]}
                />
                <TextInput
                  value={confirm}
                  onChangeText={(value) => setConfirm(value.replace(/\D/g, '').slice(0, 6))}
                  secureTextEntry
                  keyboardType="number-pad"
                  placeholder="Confirm PIN"
                  placeholderTextColor={theme.inkMuted}
                  style={[styles.modalInput, { color: theme.ink, borderColor: theme.line }]}
                />
                <View style={styles.modalActions}>
                  <Pressable onPress={closeModal}>
                    <Text style={[styles.cancel, { color: theme.inkMuted }]}>Cancel</Text>
                  </Pressable>
                  <Pressable onPress={savePin} style={[styles.primary, { backgroundColor: theme.primary }]}>
                    <Text style={styles.primaryText}>{pinModal === 'change' ? 'Save' : 'Enable'}</Text>
                  </Pressable>
                </View>
              </>
            )}
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  top: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: spacing.md },
  section: { fontSize: 18, fontWeight: '800', marginTop: spacing.lg, marginBottom: spacing.sm },
  card: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md },
  label: { fontSize: 14, fontWeight: '800' },
  caption: { fontSize: 11, marginTop: 4 },
  pills: { flexDirection: 'row', marginTop: spacing.sm },
  settingRow: { flexDirection: 'row', alignItems: 'center', paddingVertical: 14, marginTop: 5 },
  copy: { flex: 1 },
  note: { flexDirection: 'row', gap: 9, padding: spacing.md, borderRadius: radius.md, marginTop: spacing.lg },
  noteText: { flex: 1, fontSize: 12, lineHeight: 18, fontWeight: '600' },
  modalBackdrop: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(0,0,0,.35)' },
  modal: { borderTopLeftRadius: 24, borderTopRightRadius: 24, padding: spacing.lg },
  modalTitle: { fontSize: 21, fontWeight: '800' },
  modalInput: { borderWidth: 1, borderRadius: radius.sm, padding: spacing.md, fontSize: 17, marginTop: spacing.md },
  modalActions: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'flex-end',
    gap: spacing.lg,
    marginTop: spacing.lg,
  },
  cancel: { fontSize: 13, fontWeight: '700' },
  primary: { borderRadius: radius.pill, paddingHorizontal: 17, paddingVertical: 11 },
  primaryText: { color: '#fff', fontWeight: '800' },
});
