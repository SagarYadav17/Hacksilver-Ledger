import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter, useLocalSearchParams } from 'expo-router';
import { useAccounts, useReconcileAccount, useTransactions } from '@/data/hooks';
import { formatCurrency, formatDate } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Screen, TransactionRow } from '@/components/ui';
import { useAppStore } from '@/store/app-store';

export default function AccountDetailsScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id: string }>();
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const currency = useAppStore((state) => state.currency);
  const accounts = useAccounts();
  const transactions = useTransactions({ sort: 'date_desc' });
  const reconcile = useReconcileAccount();
  const [reconcileOpen, setReconcileOpen] = useState(false);
  const [reconciledBalance, setReconciledBalance] = useState('');
  const account = accounts.data?.find((item) => item.id === id);
  const items = transactions.data?.filter((item) => item.accountId === id || item.transferAccountId === id) ?? [];

  if (!account)
    return (
      <Screen>
        <Text style={{ color: theme.ink }}>Account not found.</Text>
      </Screen>
    );

  const openReconcile = () => {
    setReconciledBalance(String(account.balance));
    setReconcileOpen(true);
  };
  const saveReconcile = () => {
    const balance = Number(reconciledBalance.replace(/,/g, ''));
    if (!Number.isFinite(balance)) {
      Alert.alert('Check the balance', 'Enter the current balance shown by your bank or wallet.');
      return;
    }
    reconcile.mutate(
      { id: account.id, balance },
      {
        onSuccess: () => setReconcileOpen(false),
        onError: (error) => Alert.alert('Could not reconcile', error.message),
      },
    );
  };

  return (
    <>
      <Screen>
        <View style={styles.top}>
          <Pressable onPress={() => router.back()}>
            <MaterialIcons name="arrow-back" size={24} color={theme.ink} />
          </Pressable>
          <Text style={[styles.topTitle, { color: theme.ink }]}>Account details</Text>
          <View style={{ width: 24 }} />
        </View>
        <View style={[styles.hero, { backgroundColor: theme.primary }]}>
          <Text style={styles.heroLabel}>{account.name.toUpperCase()}</Text>
          <Text style={styles.heroValue}>{formatCurrency(account.balance, currency, hidden)}</Text>
          <Text style={styles.heroHint}>
            {account.type.replace('_', ' ')} · updated {formatDate(account.updatedAt)}
          </Text>
          <Pressable onPress={openReconcile} style={styles.reconcileButton}>
            <MaterialIcons name="fact-check" size={17} color={theme.primary} />
            <Text style={[styles.reconcileText, { color: theme.primary }]}>Reconcile balance</Text>
          </Pressable>
        </View>
        <View style={styles.statRow}>
          <View style={[styles.stat, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            <Text style={[styles.statLabel, { color: theme.inkMuted }]}>ACTIVITY</Text>
            <Text style={[styles.statValue, { color: theme.ink }]}>{items.length}</Text>
          </View>
          <View style={[styles.stat, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            <Text style={[styles.statLabel, { color: theme.inkMuted }]}>STATUS</Text>
            <Text style={[styles.statValue, { color: theme.primary }]}>Active</Text>
          </View>
        </View>
        <Text style={[styles.section, { color: theme.ink }]}>Recent activity</Text>
        {items.length ? (
          <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            {items.map((item) => (
              <TransactionRow key={item.id} transaction={item} />
            ))}
          </View>
        ) : (
          <View style={[styles.empty, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            <Text style={[styles.emptyText, { color: theme.inkMuted }]}>
              No transactions connected to this account yet.
            </Text>
          </View>
        )}
        <Pressable
          onPress={() => router.push('/transaction/new')}
          style={[styles.add, { backgroundColor: theme.primary }]}
        >
          <MaterialIcons name="add" size={18} color={theme.white} />
          <Text style={styles.addText}>Add transaction</Text>
        </Pressable>
      </Screen>
      <Modal visible={reconcileOpen} transparent animationType="slide" onRequestClose={() => setReconcileOpen(false)}>
        <KeyboardAvoidingView behavior="padding" style={styles.modalBackdrop}>
          <View style={[styles.modal, { backgroundColor: theme.surface }]}>
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: theme.ink }]}>Reconcile balance</Text>
              <Pressable onPress={() => setReconcileOpen(false)}>
                <MaterialIcons name="close" size={22} color={theme.inkMuted} />
              </Pressable>
            </View>
            <Text style={[styles.modalCaption, { color: theme.inkMuted }]}>
              Enter the balance currently shown by {account.name}. This keeps future entries accurate while preserving
              your activity history.
            </Text>
            <TextInput
              value={reconciledBalance}
              onChangeText={setReconciledBalance}
              keyboardType="decimal-pad"
              style={[styles.modalInput, { backgroundColor: theme.canvas, borderColor: theme.line, color: theme.ink }]}
              autoFocus
            />
            <Pressable
              disabled={reconcile.isPending}
              onPress={saveReconcile}
              style={[styles.modalSave, { backgroundColor: theme.primary }]}
            >
              <Text style={styles.modalSaveText}>{reconcile.isPending ? 'Saving…' : 'Save balance'}</Text>
            </Pressable>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  top: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingTop: spacing.lg,
    paddingBottom: spacing.lg,
  },
  topTitle: { fontSize: 17, fontWeight: '800' },
  hero: { borderRadius: radius.lg, padding: spacing.lg },
  heroLabel: { color: 'rgba(255,255,255,.7)', fontSize: 11, fontWeight: '800', letterSpacing: 1.2 },
  heroValue: { color: '#fff', fontSize: 34, fontWeight: '800', marginVertical: 18 },
  heroHint: { color: 'rgba(255,255,255,.75)', fontSize: 12 },
  reconcileButton: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    backgroundColor: '#fff',
    borderRadius: radius.pill,
    paddingHorizontal: 13,
    paddingVertical: 9,
    marginTop: 17,
  },
  reconcileText: { fontSize: 12, fontWeight: '800' },
  statRow: { flexDirection: 'row', gap: spacing.sm, marginTop: spacing.sm },
  stat: { flex: 1, borderWidth: 1, borderRadius: radius.md, padding: spacing.md },
  statLabel: { fontSize: 10, fontWeight: '800', letterSpacing: 1 },
  statValue: { fontSize: 19, fontWeight: '800', marginTop: 8 },
  section: { fontSize: 18, fontWeight: '800', marginTop: spacing.xl, marginBottom: spacing.sm },
  card: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
  empty: { borderWidth: 1, borderRadius: radius.md, padding: spacing.lg },
  emptyText: { textAlign: 'center', fontSize: 13 },
  add: {
    alignSelf: 'center',
    flexDirection: 'row',
    gap: 7,
    alignItems: 'center',
    borderRadius: radius.pill,
    paddingHorizontal: 17,
    paddingVertical: 12,
    marginTop: spacing.lg,
  },
  addText: { color: '#fff', fontWeight: '800', fontSize: 13 },
  modalBackdrop: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(15, 25, 20, .36)' },
  modal: { borderTopLeftRadius: radius.lg, borderTopRightRadius: radius.lg, padding: spacing.lg, paddingBottom: 30 },
  modalHeader: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  modalTitle: { fontSize: 20, fontWeight: '800' },
  modalCaption: { fontSize: 12, lineHeight: 18, marginTop: 6 },
  modalInput: {
    borderWidth: 1,
    borderRadius: radius.md,
    padding: spacing.md,
    fontSize: 25,
    fontWeight: '800',
    marginTop: spacing.lg,
  },
  modalSave: { alignItems: 'center', borderRadius: radius.pill, paddingVertical: 14, marginTop: spacing.lg },
  modalSaveText: { color: '#fff', fontSize: 14, fontWeight: '800' },
});
