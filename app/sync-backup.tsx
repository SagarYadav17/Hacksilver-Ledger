import { useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  KeyboardAvoidingView,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useSQLiteContext } from 'expo-sqlite';
import { useQueryClient } from '@tanstack/react-query';
import {
  decryptBackup,
  exportBackup,
  MIN_PASSPHRASE_LENGTH,
  pickBackup,
  restoreCheckpoint,
  restorePayload,
  type BackupPayload,
  type EncryptedBackup,
} from '@/data/backup';
import type { BackupRecord } from '@/domain/types';
import { syncService } from '@/data/sync';
import { useBackupHistory } from '@/data/hooks';
import { useAppStore } from '@/store/app-store';
import { formatDate } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Header, Pill, Screen } from '@/components/ui';

// iOS drops alerts presented while a Modal is still animating out.
const afterModal = (show: () => void) => setTimeout(show, 350);

export default function SyncBackupScreen() {
  const router = useRouter();
  const db = useSQLiteContext();
  const queryClient = useQueryClient();
  const { colors: theme } = useAppTheme();
  const syncState = useAppStore((state) => state.syncState);
  const setSyncState = useAppStore((state) => state.setSyncState);
  const lastSyncAt = useAppStore((state) => state.lastSyncAt);
  const history = useBackupHistory();
  const [url, setUrl] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [loggedIn, setLoggedIn] = useState(false);
  const [prompt, setPrompt] = useState<{ mode: 'export' } | { mode: 'restore'; envelope: EncryptedBackup } | null>(
    null,
  );
  const [passphrase, setPassphrase] = useState('');
  const [confirmPassphrase, setConfirmPassphrase] = useState('');
  const [promptError, setPromptError] = useState('');
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    syncService.restoreSession().then((client) => {
      if (client) {
        setLoggedIn(true);
        setEmail(syncService.email ?? '');
      }
    });
  }, []);

  const configure = async () => {
    try {
      await syncService.configure(url);
      Alert.alert('Server connected', 'Now sign up or log in to enable sync.');
    } catch (error) {
      Alert.alert('Could not connect', error instanceof Error ? error.message : 'Invalid URL');
    }
  };

  const logout = async () => {
    await syncService.logout();
    setLoggedIn(false);
    setEmail('');
    setPassword('');
    setSyncState('idle');
  };

  const login = async (signup = false) => {
    try {
      setSyncState('syncing');
      if (signup) await syncService.signup(email, password);
      else await syncService.login(email, password);
      setLoggedIn(true);
      setSyncState('synced', new Date().toISOString());
      Alert.alert(signup ? 'Account created' : 'Welcome back', 'Your cloud is ready.');
    } catch (error) {
      setSyncState('error');
      Alert.alert('Authentication failed', error instanceof Error ? error.message : 'Try again');
    }
  };

  const sync = async () => {
    setSyncState('syncing');
    const result = await syncService.sync(db);
    if (result.success) {
      setSyncState(result.conflicts ? 'conflict' : 'synced', new Date().toISOString());
      Alert.alert(
        result.error ? 'Sync partly complete' : 'Sync complete',
        `${result.pushed} pushed · ${result.pulled} pulled${result.conflicts ? ` · ${result.conflicts} conflicts recorded` : ''}${result.error ? `\n${result.error}` : ''}`,
      );
    } else {
      setSyncState('error');
      Alert.alert('Sync needs attention', result.error ?? 'Try again');
    }
  };

  const refreshAll = () =>
    Promise.all(
      ['dashboard', 'accounts', 'categories', 'transactions', 'loans', 'recurring', 'backup-history'].map((queryKey) =>
        queryClient.invalidateQueries({ queryKey: [queryKey] }),
      ),
    );

  const openPrompt = (next: NonNullable<typeof prompt>) => {
    setPassphrase('');
    setConfirmPassphrase('');
    setPromptError('');
    setPrompt(next);
  };

  const closePrompt = () => {
    if (busy) return;
    setPassphrase('');
    setConfirmPassphrase('');
    setPrompt(null);
  };

  const confirmReplace = (title: string, message: string, restore: () => Promise<void>) =>
    Alert.alert(title, message, [
      { text: 'Cancel', style: 'cancel' },
      {
        text: 'Restore',
        style: 'destructive',
        onPress: async () => {
          try {
            await restore();
            await refreshAll();
            Alert.alert('Restore complete', 'Your previous ledger was saved as a restore checkpoint.');
          } catch (error) {
            Alert.alert('Restore failed', error instanceof Error ? error.message : 'Try again');
          }
        },
      },
    ]);

  const restorePicked = (payload: BackupPayload) =>
    confirmReplace(
      'Replace local ledger?',
      'Restore will replace the data on this device with the selected backup. A checkpoint of the current data is kept.',
      () => restorePayload(db, payload),
    );

  const startRestore = async () => {
    try {
      const picked = await pickBackup();
      if (!picked) return;
      if (picked.version === 2) openPrompt({ mode: 'restore', envelope: picked.envelope });
      else
        confirmReplace(
          'Unencrypted backup',
          'This older backup is not encrypted and its checksum cannot prove it was not modified. Only restore files you created yourself. A checkpoint of the current data is kept.',
          () => restorePayload(db, picked.payload),
        );
    } catch (error) {
      Alert.alert('Restore failed', error instanceof Error ? error.message : 'Try again');
    }
  };

  const submitPrompt = async () => {
    if (!prompt || busy) return;
    if (prompt.mode === 'export') {
      if (passphrase.length < MIN_PASSPHRASE_LENGTH)
        return setPromptError(`Use at least ${MIN_PASSPHRASE_LENGTH} characters.`);
      if (passphrase !== confirmPassphrase) return setPromptError('Passphrases do not match.');
    }
    setBusy(true);
    setPromptError('');
    try {
      if (prompt.mode === 'export') {
        await exportBackup(db, passphrase);
        await queryClient.invalidateQueries({ queryKey: ['backup-history'] });
        setPrompt(null);
        afterModal(() =>
          Alert.alert('Backup shared', 'Keep your passphrase safe — the backup cannot be opened without it.'),
        );
      } else {
        const payload = await decryptBackup(prompt.envelope, passphrase);
        setPrompt(null);
        afterModal(() => restorePicked(payload));
      }
      setPassphrase('');
      setConfirmPassphrase('');
    } catch (error) {
      setPromptError(error instanceof Error ? error.message : 'Try again');
    } finally {
      setBusy(false);
    }
  };

  const restoreFromCheckpoint = (record: BackupRecord) =>
    confirmReplace(
      'Restore checkpoint?',
      'Your ledger will return to how it was before that restore. The current data is saved as a new checkpoint.',
      () => restoreCheckpoint(db, record),
    );

  return (
    <Screen>
      <View style={styles.top}>
        <Pressable onPress={() => router.back()}>
          <MaterialIcons name="arrow-back" size={24} color={theme.ink} />
        </Pressable>
        <Header eyebrow="Your data" title="Sync & backup" />
        <View style={{ width: 24 }} />
      </View>
      <View style={[styles.hero, { backgroundColor: theme.primary }]}>
        <MaterialIcons name="cloud-sync" size={26} color={theme.white} />
        <Text style={styles.heroTitle}>{loggedIn ? 'Cloud connected' : 'Keep a private copy'}</Text>
        <Text style={styles.heroText}>
          {loggedIn
            ? `Signed in as ${email}`
            : 'The ledger is fully useful offline. Add PocketBase only when you want another device.'}
        </Text>
        <View style={styles.heroActions}>
          {loggedIn ? (
            <>
              <Pressable onPress={sync} style={styles.heroButton}>
                <Text style={[styles.heroButtonText, { color: theme.primary }]}>
                  {syncState === 'syncing' ? 'Syncing…' : 'Sync now'}
                </Text>
              </Pressable>
              <Pressable onPress={logout} style={styles.heroLink}>
                <Text style={styles.heroLinkText}>Log out</Text>
              </Pressable>
            </>
          ) : null}
        </View>
      </View>
      {!loggedIn && (
        <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          <Text style={[styles.sectionTitle, { color: theme.ink }]}>PocketBase</Text>
          <Text style={[styles.caption, { color: theme.inkMuted }]}>
            Use your own server. The app never needs admin credentials.
          </Text>
          <TextInput
            value={url}
            onChangeText={setUrl}
            autoCapitalize="none"
            placeholder="https://your-server.example"
            placeholderTextColor={theme.inkMuted}
            style={[styles.input, { color: theme.ink, borderColor: theme.line }]}
          />
          <Pressable onPress={configure} style={[styles.outlineButton, { borderColor: theme.primary }]}>
            <Text style={[styles.outlineText, { color: theme.primary }]}>Connect server</Text>
          </Pressable>
          <TextInput
            value={email}
            onChangeText={setEmail}
            autoCapitalize="none"
            keyboardType="email-address"
            placeholder="Email"
            placeholderTextColor={theme.inkMuted}
            style={[styles.input, { color: theme.ink, borderColor: theme.line }]}
          />
          <TextInput
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            placeholder="Password"
            placeholderTextColor={theme.inkMuted}
            style={[styles.input, { color: theme.ink, borderColor: theme.line }]}
          />
          <View style={styles.authRow}>
            <Pill label="Log in" selected onPress={() => login(false)} />
            <Pill label="Create account" onPress={() => login(true)} />
          </View>
        </View>
      )}
      <Text style={[styles.section, { color: theme.ink }]}>Local safety</Text>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        <View style={styles.safetyRow}>
          <MaterialIcons name="verified-user" size={21} color={theme.primary} />
          <View style={styles.copy}>
            <Text style={[styles.sectionTitle, { color: theme.ink }]}>Export a portable backup</Text>
            <Text style={[styles.caption, { color: theme.inkMuted }]}>
              Encrypted with your passphrase. Restores keep a checkpoint on this device.
            </Text>
          </View>
        </View>
        <View style={styles.buttons}>
          <Pressable
            onPress={() => openPrompt({ mode: 'export' })}
            style={[styles.outlineButton, { borderColor: theme.line }]}
          >
            <Text style={[styles.outlineText, { color: theme.ink }]}>Export</Text>
          </Pressable>
          <Pressable onPress={startRestore} style={[styles.outlineButton, { borderColor: theme.line }]}>
            <Text style={[styles.outlineText, { color: theme.ink }]}>Restore</Text>
          </Pressable>
        </View>
      </View>
      {history.data?.length ? (
        <>
          <Text style={[styles.section, { color: theme.ink }]}>Backup history</Text>
          <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            {history.data.slice(0, 5).map((record) => (
              <View key={record.id} style={styles.historyRow}>
                <MaterialIcons name="check-circle-outline" size={18} color={theme.primary} />
                <View style={styles.copy}>
                  <Text style={[styles.sectionTitle, { color: theme.ink }]}>
                    {record.kind === 'export' ? 'Exported backup' : 'Restore checkpoint'}
                  </Text>
                  <Text style={[styles.caption, { color: theme.inkMuted }]}>
                    {formatDate(record.createdAt, {
                      day: 'numeric',
                      month: 'short',
                      hour: 'numeric',
                      minute: '2-digit',
                    })}{' '}
                    · {Math.max(1, Math.round(record.sizeBytes / 1024))} KB
                  </Text>
                </View>
                {record.kind === 'pre_restore' && (
                  <Pressable onPress={() => restoreFromCheckpoint(record)} hitSlop={8}>
                    <Text style={[styles.outlineText, { color: theme.primary }]}>Restore</Text>
                  </Pressable>
                )}
              </View>
            ))}
          </View>
        </>
      ) : null}
      {lastSyncAt && (
        <Text style={[styles.caption, { color: theme.inkMuted, textAlign: 'center', marginTop: spacing.lg }]}>
          Last sync {formatDate(lastSyncAt, { day: 'numeric', month: 'short', hour: 'numeric', minute: '2-digit' })}
        </Text>
      )}
      <Modal visible={prompt !== null} transparent animationType="fade" onRequestClose={closePrompt}>
        <KeyboardAvoidingView behavior="padding" style={styles.backdrop}>
          <View style={[styles.sheet, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            <Text style={[styles.sectionTitle, { color: theme.ink }]}>
              {prompt?.mode === 'export' ? 'Protect this backup' : 'Unlock backup'}
            </Text>
            <Text style={[styles.caption, { color: theme.inkMuted }]}>
              {prompt?.mode === 'export'
                ? `Choose a passphrase of at least ${MIN_PASSPHRASE_LENGTH} characters. It cannot be recovered if lost.`
                : 'Enter the passphrase used when this backup was exported.'}
            </Text>
            <TextInput
              autoFocus
              value={passphrase}
              onChangeText={setPassphrase}
              secureTextEntry
              autoCapitalize="none"
              autoCorrect={false}
              placeholder="Passphrase"
              placeholderTextColor={theme.inkMuted}
              editable={!busy}
              onSubmitEditing={prompt?.mode === 'export' ? undefined : submitPrompt}
              style={[styles.input, { color: theme.ink, borderColor: theme.line }]}
            />
            {prompt?.mode === 'export' && (
              <TextInput
                value={confirmPassphrase}
                onChangeText={setConfirmPassphrase}
                secureTextEntry
                autoCapitalize="none"
                autoCorrect={false}
                placeholder="Confirm passphrase"
                placeholderTextColor={theme.inkMuted}
                editable={!busy}
                onSubmitEditing={submitPrompt}
                style={[styles.input, { color: theme.ink, borderColor: theme.line }]}
              />
            )}
            {promptError ? <Text style={[styles.caption, { color: theme.expense }]}>{promptError}</Text> : null}
            <View style={styles.buttons}>
              <Pressable onPress={closePrompt} style={[styles.outlineButton, { borderColor: theme.line }]}>
                <Text style={[styles.outlineText, { color: theme.ink }]}>Cancel</Text>
              </Pressable>
              <Pressable
                onPress={submitPrompt}
                style={[styles.outlineButton, { borderColor: theme.primary, backgroundColor: theme.primary }]}
              >
                {busy ? (
                  <ActivityIndicator size="small" color={theme.white} />
                ) : (
                  <Text style={[styles.outlineText, { color: theme.white }]}>
                    {prompt?.mode === 'export' ? 'Encrypt & share' : 'Unlock'}
                  </Text>
                )}
              </Pressable>
            </View>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </Screen>
  );
}

const styles = StyleSheet.create({
  top: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: spacing.md },
  hero: { borderRadius: radius.lg, padding: spacing.lg },
  heroTitle: { color: '#fff', fontSize: 20, fontWeight: '800', marginTop: 18 },
  heroText: { color: 'rgba(255,255,255,.75)', fontSize: 12, lineHeight: 18, marginTop: 5 },
  heroActions: { flexDirection: 'row', alignItems: 'center', gap: 14 },
  heroButton: {
    alignSelf: 'flex-start',
    backgroundColor: '#fff',
    borderRadius: radius.pill,
    paddingHorizontal: 14,
    paddingVertical: 10,
    marginTop: 17,
  },
  heroButtonText: { fontSize: 12, fontWeight: '800' },
  heroLink: { marginTop: 17, paddingVertical: 10 },
  heroLinkText: { color: '#fff', fontSize: 12, fontWeight: '800' },
  card: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, marginTop: spacing.md },
  sectionTitle: { fontSize: 15, fontWeight: '800' },
  section: { fontSize: 18, fontWeight: '800', marginTop: spacing.xl, marginBottom: spacing.sm },
  caption: { fontSize: 11, lineHeight: 17, marginTop: 4 },
  input: { borderWidth: 1, borderRadius: radius.sm, padding: 12, fontSize: 13, marginTop: 10 },
  outlineButton: {
    borderWidth: 1,
    borderRadius: radius.pill,
    paddingHorizontal: 14,
    paddingVertical: 10,
    alignSelf: 'flex-start',
    marginTop: 11,
  },
  outlineText: { fontSize: 12, fontWeight: '800' },
  authRow: { flexDirection: 'row', marginTop: 6 },
  safetyRow: { flexDirection: 'row', alignItems: 'center', gap: 10 },
  copy: { flex: 1 },
  historyRow: { flexDirection: 'row', alignItems: 'center', gap: 10, paddingVertical: 8 },
  buttons: { flexDirection: 'row', gap: 8, marginTop: 5 },
  backdrop: { flex: 1, justifyContent: 'center', padding: spacing.lg, backgroundColor: 'rgba(0,0,0,.45)' },
  sheet: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md },
});
