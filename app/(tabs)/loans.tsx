import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Modal, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAccounts, useLoans, useRecordLoanPayment } from '@/data/hooks';
import { scheduleLoanReminder } from '@/data/notifications';
import { formatCurrency, formatDate } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { EmptyState, Header, Screen } from '@/components/ui';
import { useAppStore } from '@/store/app-store';
import type { Loan } from '@/domain/types';

export default function LoansScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const currency = useAppStore((state) => state.currency);
  const loans = useLoans();
  const accounts = useAccounts();
  const pay = useRecordLoanPayment();
  const [expanded, setExpanded] = useState<string | null>(null);
  const [paymentLoan, setPaymentLoan] = useState<Loan | null>(null);
  const [paymentAmount, setPaymentAmount] = useState('');
  const [paymentAccountId, setPaymentAccountId] = useState<string | null>(null);
  const [nextPaymentDate] = useState(() => new Date(Date.now() + 30 * 86400000).toISOString());

  const openPayment = (loan: Loan) => {
    const remaining = Math.max(0, loan.amount - loan.amountPaid);
    setPaymentLoan(loan);
    setPaymentAmount(String(Math.min(remaining, loan.emiAmount || 1000)));
    setPaymentAccountId(accounts.data?.[0]?.id ?? null);
  };

  const submitPayment = () => {
    if (!paymentLoan) return;
    const remaining = Math.max(0, paymentLoan.amount - paymentLoan.amountPaid);
    const amount = Number(paymentAmount.replace(/,/g, ''));
    if (!Number.isFinite(amount) || amount <= 0 || amount > remaining) {
      Alert.alert('Check the amount', `Enter a payment between 0 and ${formatCurrency(remaining, currency)}.`);
      return;
    }
    pay.mutate(
      { loanId: paymentLoan.id, amount, accountId: paymentAccountId },
      {
        onSuccess: () => setPaymentLoan(null),
        onError: (error) => Alert.alert('Could not record payment', error.message),
      },
    );
  };

  const remind = async (title: string) => {
    const scheduled = await scheduleLoanReminder(title, new Date(nextPaymentDate));
    Alert.alert(
      scheduled ? 'Reminder set' : 'Reminder unavailable',
      scheduled
        ? 'You will be reminded one day before the next payment.'
        : 'Allow notifications and use a future payment date to set reminders.',
    );
  };

  return (
    <>
      <Screen>
        <Header eyebrow="Borrowed & lent" title="Loans" action="Add loan" onAction={() => router.push('/loan/new')} />
        {loans.data?.length ? (
          loans.data.map((loan) => {
            const remaining = Math.max(0, loan.amount - loan.amountPaid);
            const progress = loan.amount ? Math.min(1, loan.amountPaid / loan.amount) : 0;
            const isExpanded = expanded === loan.id;
            return (
              <View key={loan.id} style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
                <View style={styles.cardTop}>
                  <View
                    style={[
                      styles.loanIcon,
                      { backgroundColor: loan.type === 'given' ? theme.incomeSoft : theme.expenseSoft },
                    ]}
                  >
                    <MaterialIcons
                      name={loan.type === 'given' ? 'north-east' : 'south-west'}
                      size={20}
                      color={loan.type === 'given' ? theme.income : theme.expense}
                    />
                  </View>
                  <View style={styles.copy}>
                    <Text style={[styles.title, { color: theme.ink }]}>{loan.title}</Text>
                    <Text style={[styles.meta, { color: theme.inkMuted }]}>
                      {loan.type === 'given' ? 'You lent' : 'You borrowed'} · started {formatDate(loan.startDate)}
                    </Text>
                  </View>
                  <Text style={[styles.amount, { color: theme.ink }]}>
                    {formatCurrency(remaining, currency, hidden)}
                  </Text>
                </View>
                <View style={[styles.progressTrack, { backgroundColor: theme.surfaceAlt }]}>
                  <View
                    style={[
                      styles.progress,
                      {
                        backgroundColor: loan.type === 'given' ? theme.income : theme.expense,
                        width: `${progress * 100}%`,
                      },
                    ]}
                  />
                </View>
                <View style={styles.bottom}>
                  <Text style={[styles.progressLabel, { color: theme.inkMuted }]}>
                    {Math.round(progress * 100)}% repaid · EMI {formatCurrency(loan.emiAmount, currency, hidden)}
                  </Text>
                  <Pressable onPress={() => setExpanded(isExpanded ? null : loan.id)}>
                    <Text style={[styles.action, { color: theme.primary }]}>{isExpanded ? 'Hide' : 'Manage'}</Text>
                  </Pressable>
                </View>
                {isExpanded && (
                  <View style={[styles.actions, { borderTopColor: theme.line }]}>
                    <Pressable
                      onPress={() => openPayment(loan)}
                      style={[styles.actionButton, { backgroundColor: theme.primary }]}
                    >
                      <MaterialIcons name="add" size={16} color={theme.white} />
                      <Text style={styles.actionButtonText}>Record payment</Text>
                    </Pressable>
                    <Pressable
                      onPress={() => remind(loan.title)}
                      style={[styles.actionButton, { backgroundColor: theme.surfaceAlt, marginTop: 8 }]}
                    >
                      <MaterialIcons name="notifications-none" size={16} color={theme.primary} />
                      <Text style={[styles.actionButtonText, { color: theme.primary }]}>Remind me</Text>
                    </Pressable>
                    <Text style={[styles.timeline, { color: theme.inkMuted }]}>
                      Next: {formatDate(nextPaymentDate)} ·{' '}
                      {remaining > 0 ? `${loan.tenureMonths} month plan` : 'Complete'}
                    </Text>
                  </View>
                )}
              </View>
            );
          })
        ) : (
          <EmptyState
            icon="handshake"
            title="Track money in motion"
            message="Keep borrowed and lent money visible with clear repayment progress and reminders."
            action="Add loan"
            onAction={() => router.push('/loan/new')}
          />
        )}
      </Screen>
      <Modal
        visible={Boolean(paymentLoan)}
        transparent
        animationType="slide"
        onRequestClose={() => setPaymentLoan(null)}
      >
        <KeyboardAvoidingView behavior="padding" style={styles.modalBackdrop}>
          <View style={[styles.modalCard, { backgroundColor: theme.surface }]}>
            <View style={styles.modalHeader}>
              <Text style={[styles.modalTitle, { color: theme.ink }]}>Record payment</Text>
              <Pressable onPress={() => setPaymentLoan(null)}>
                <MaterialIcons name="close" size={22} color={theme.inkMuted} />
              </Pressable>
            </View>
            <Text style={[styles.modalCaption, { color: theme.inkMuted }]}>{paymentLoan?.title}</Text>
            <Text style={[styles.modalLabel, { color: theme.inkMuted }]}>AMOUNT</Text>
            <View style={[styles.amountField, { backgroundColor: theme.canvas, borderColor: theme.line }]}>
              <Text style={[styles.currency, { color: theme.inkMuted }]}>₹</Text>
              <TextInput
                value={paymentAmount}
                onChangeText={setPaymentAmount}
                keyboardType="decimal-pad"
                style={[styles.amountInput, { color: theme.ink }]}
                autoFocus
              />
            </View>
            {accounts.data?.length ? (
              <>
                <Text style={[styles.modalLabel, { color: theme.inkMuted }]}>ACCOUNT</Text>
                <View style={styles.accountPills}>
                  {accounts.data.map((account) => (
                    <Pressable
                      key={account.id}
                      onPress={() => setPaymentAccountId(account.id)}
                      style={[
                        styles.accountPill,
                        {
                          backgroundColor: paymentAccountId === account.id ? theme.primarySoft : theme.canvas,
                          borderColor: paymentAccountId === account.id ? theme.primary : theme.line,
                        },
                      ]}
                    >
                      <Text
                        style={[
                          styles.accountPillText,
                          { color: paymentAccountId === account.id ? theme.primary : theme.ink },
                        ]}
                      >
                        {account.name}
                      </Text>
                    </Pressable>
                  ))}
                </View>
              </>
            ) : null}
            <Pressable
              disabled={pay.isPending}
              onPress={submitPayment}
              style={[styles.modalSave, { backgroundColor: theme.primary }]}
            >
              <Text style={styles.modalSaveText}>{pay.isPending ? 'Saving…' : 'Save payment'}</Text>
            </Pressable>
          </View>
        </KeyboardAvoidingView>
      </Modal>
    </>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, marginBottom: spacing.sm },
  cardTop: { flexDirection: 'row', alignItems: 'center' },
  loanIcon: {
    width: 42,
    height: 42,
    borderRadius: 14,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 11,
  },
  copy: { flex: 1 },
  title: { fontSize: 15, fontWeight: '800' },
  meta: { fontSize: 11, marginTop: 4 },
  amount: { fontSize: 16, fontWeight: '800' },
  progressTrack: { height: 7, borderRadius: 5, overflow: 'hidden', marginTop: 18 },
  progress: { height: 7, borderRadius: 5 },
  bottom: { flexDirection: 'row', justifyContent: 'space-between', marginTop: 9 },
  progressLabel: { fontSize: 11 },
  action: { fontSize: 12, fontWeight: '800' },
  actions: { borderTopWidth: 1, marginTop: 13, paddingTop: 13 },
  actionButton: {
    alignSelf: 'flex-start',
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingVertical: 9,
    paddingHorizontal: 12,
    borderRadius: radius.pill,
  },
  actionButtonText: { color: '#fff', fontSize: 12, fontWeight: '800' },
  timeline: { fontSize: 11, marginTop: 12 },
  modalBackdrop: { flex: 1, justifyContent: 'flex-end', backgroundColor: 'rgba(15, 25, 20, .36)' },
  modalCard: {
    borderTopLeftRadius: radius.lg,
    borderTopRightRadius: radius.lg,
    padding: spacing.lg,
    paddingBottom: 30,
  },
  modalHeader: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  modalTitle: { fontSize: 20, fontWeight: '800' },
  modalCaption: { fontSize: 13, marginTop: 5 },
  modalLabel: { fontSize: 11, letterSpacing: 1.2, fontWeight: '800', marginTop: spacing.lg, marginBottom: spacing.sm },
  amountField: {
    borderWidth: 1,
    borderRadius: radius.md,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
  },
  currency: { fontSize: 24, fontWeight: '700' },
  amountInput: { flex: 1, fontSize: 30, fontWeight: '800', paddingVertical: 10, marginLeft: 8 },
  accountPills: { flexDirection: 'row', flexWrap: 'wrap', gap: 8 },
  accountPill: { borderWidth: 1, borderRadius: radius.pill, paddingHorizontal: 13, paddingVertical: 9 },
  accountPillText: { fontSize: 12, fontWeight: '700' },
  modalSave: { alignItems: 'center', borderRadius: radius.pill, paddingVertical: 14, marginTop: spacing.xl },
  modalSaveText: { color: '#fff', fontSize: 14, fontWeight: '800' },
});
