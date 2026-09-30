import { useMemo, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAccounts, useDashboardSummary, useTransactions } from '@/data/hooks';
import { formatCurrency, formatDate } from '@/lib/format';
import { colors, radius, spacing, useAppTheme } from '@/lib/theme';
import { useAppStore } from '@/store/app-store';
import {
  AccountRow,
  AnimatedEntry,
  BalanceChart,
  EmptyState,
  Header,
  LoadingBlock,
  MotionPressable,
  Screen,
  SectionHeader,
  TransactionRow,
} from '@/components/ui';

type Range = 'month' | 'year';

export default function DashboardScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const currency = useAppStore((state) => state.currency);
  const [range, setRange] = useState<Range>('month');
  const summary = useDashboardSummary();
  const transactions = useTransactions({ sort: 'date_desc' });
  const accounts = useAccounts();
  const accountById = new Map((accounts.data ?? []).map((account) => [account.id, account]));
  const recent = transactions.data?.slice(0, 4) ?? [];
  const accountName = accounts.data?.[0]?.name ?? 'Personal account';
  const today = new Date().toISOString();

  const chart = useMemo(() => {
    const ordered = [...(transactions.data ?? [])]
      .sort((a, b) => new Date(a.date).getTime() - new Date(b.date).getTime())
      .slice(-10);
    // Balance reconstruction: adjustments move balances (signed); transfers net to zero.
    const delta = (type: string, amount: number) =>
      type === 'income' || type === 'adjustment' ? amount : type === 'expense' ? -amount : 0;
    const ending = summary.data?.balance ?? 0;
    let opening = ending - ordered.reduce((total, item) => total + delta(item.type, item.amount), 0);
    const values = [opening];
    ordered.forEach((item) => {
      opening += delta(item.type, item.amount);
      values.push(opening);
    });
    if (values.length === 1) values.push(ending);
    values.push(ending);
    return { values, markerIndex: Math.max(0, values.length - 2) };
  }, [summary.data?.balance, transactions.data]);

  return (
    <Screen>
      <View style={styles.topRow}>
        <MotionPressable
          accessibilityLabel="Open account overview"
          onPress={() => router.push('/(tabs)/accounts')}
          style={[styles.accountChip, { backgroundColor: theme.surface, borderColor: theme.line }]}
        >
          <View style={[styles.accountBadge, { backgroundColor: theme.expense }]}>
            <MaterialIcons name="person" size={23} color={theme.white} />
          </View>
          <Text numberOfLines={1} style={[styles.accountName, { color: theme.ink }]}>
            {accountName}
          </Text>
        </MotionPressable>
        <MotionPressable
          accessibilityLabel="Open activity calendar"
          onPress={() => router.push('/(tabs)/activity')}
          style={[styles.calendarButton, { backgroundColor: theme.surface, borderColor: theme.line }]}
        >
          <MaterialIcons name="calendar-month" size={24} color={theme.ink} />
        </MotionPressable>
      </View>

      <View style={styles.modeRow}>
        <DashboardMode label="Balance" icon="timeline" selected />
        <DashboardMode label="Spending" icon="bar-chart" onPress={() => router.push('/analytics')} />
        <DashboardMode label="Target" icon="my-location" onPress={() => router.push('/categories')} />
      </View>

      {summary.isLoading ? (
        <LoadingBlock />
      ) : (
        <View style={[styles.balanceCard, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          <View style={[styles.balanceSummary, { backgroundColor: theme.primarySoft }]}>
            <View>
              <Text style={[styles.date, { color: theme.ink }]}>{formatDate(today)}</Text>
              <Text style={[styles.outflow, { color: theme.inkMuted }]}>
                {formatCurrency(summary.data?.expenses ?? 0, currency, hidden)} OUT
              </Text>
            </View>
            <View style={styles.balanceValueBlock}>
              <Text style={[styles.balance, { color: theme.ink }]}>
                {formatCurrency(summary.data?.balance ?? 0, currency, hidden)}
              </Text>
              <Text style={[styles.balanceLabel, { color: theme.inkMuted }]}>End of day balance</Text>
            </View>
          </View>
          <BalanceChart values={chart.values} markerIndex={chart.markerIndex} />
          <View style={styles.chartLabels}>
            <Text style={[styles.chartLabel, { color: theme.inkMuted }]}>
              {formatDate(transactions.data?.at(-1)?.date ?? today)}
            </Text>
            <Text style={[styles.chartLabel, { color: theme.inkMuted }]}>Today</Text>
          </View>
          <Text style={[styles.updated, { color: theme.inkMuted }]}>Updated just now</Text>
        </View>
      )}

      <View style={[styles.insightCard, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        <View style={[styles.insightIcon, { backgroundColor: theme.primary }]}>
          <MaterialIcons name="my-location" size={22} color={theme.white} />
        </View>
        <Text style={[styles.insightTitle, { color: theme.ink }]}>See your spending patterns</Text>
        <Text style={[styles.insightMessage, { color: theme.inkMuted }]}>
          Understand where your money goes this month.
        </Text>
        <MotionPressable
          onPress={() => router.push('/analytics')}
          style={[styles.insightButton, { backgroundColor: theme.primary }]}
        >
          <Text style={styles.insightButtonText}>Open insights</Text>
        </MotionPressable>
      </View>

      <View style={[styles.rangeToggle, { backgroundColor: theme.surfaceAlt }]}>
        {(['month', 'year'] as const).map((value) => (
          <MotionPressable
            key={value}
            accessibilityRole="button"
            onPress={() => setRange(value)}
            style={[styles.rangeOption, range === value && { backgroundColor: theme.surface }]}
          >
            <Text style={[styles.rangeText, { color: range === value ? theme.ink : theme.inkMuted }]}>
              {value === 'month' ? 'Month' : 'Year'}
            </Text>
          </MotionPressable>
        ))}
      </View>

      <Header
        eyebrow={range === 'month' ? 'This month' : 'Year to date'}
        title="Recent activity"
        action="See all"
        onAction={() => router.push('/(tabs)/activity')}
      />
      {recent.length ? (
        <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          {recent.map((transaction, index) => (
            <AnimatedEntry key={transaction.id} delay={index * 45}>
              <TransactionRow
                transaction={transaction}
                account={accountById.get(transaction.accountId ?? '')}
                onPress={() => router.push({ pathname: '/transaction/new', params: { id: transaction.id } })}
              />
            </AnimatedEntry>
          ))}
        </View>
      ) : (
        <EmptyState
          icon="receipt-long"
          title="Start your ledger"
          message="Add your first income, expense, or transfer and your overview will come alive."
          action="Add transaction"
          onAction={() => router.push('/transaction/new')}
        />
      )}

      <SectionHeader title="Accounts" action="Manage" onAction={() => router.push('/(tabs)/accounts')} />
      {accounts.data?.length ? (
        <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          {accounts.data.slice(0, 3).map((account, index) => (
            <AnimatedEntry key={account.id} delay={index * 45}>
              <AccountRow account={account} onPress={() => router.push(`/account/${account.id}`)} />
            </AnimatedEntry>
          ))}
        </View>
      ) : null}
    </Screen>
  );
}

function DashboardMode({
  label,
  icon,
  selected = false,
  onPress,
}: {
  label: string;
  icon: keyof typeof MaterialIcons.glyphMap;
  selected?: boolean;
  onPress?: () => void;
}) {
  const { colors: theme } = useAppTheme();
  return (
    <MotionPressable
      onPress={onPress}
      style={[styles.mode, selected && { backgroundColor: theme.surface, borderColor: theme.line }]}
    >
      <MaterialIcons name={icon} size={20} color={selected ? theme.ink : theme.inkMuted} />
      <Text style={[styles.modeText, { color: selected ? theme.ink : theme.inkMuted }]}>{label}</Text>
    </MotionPressable>
  );
}

const styles = StyleSheet.create({
  topRow: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: spacing.lg },
  accountChip: {
    alignItems: 'center',
    borderRadius: radius.pill,
    borderWidth: 1,
    flexDirection: 'row',
    maxWidth: '78%',
    padding: 7,
    paddingRight: 18,
  },
  accountBadge: { alignItems: 'center', borderRadius: radius.pill, height: 42, justifyContent: 'center', width: 42 },
  accountName: { fontSize: 18, fontWeight: '700', marginLeft: 11 },
  calendarButton: {
    alignItems: 'center',
    borderRadius: radius.pill,
    borderWidth: 1,
    height: 54,
    justifyContent: 'center',
    width: 54,
  },
  modeRow: { alignItems: 'center', flexDirection: 'row', gap: 8, marginBottom: spacing.md, marginTop: spacing.lg },
  mode: {
    alignItems: 'center',
    borderColor: 'transparent',
    borderRadius: radius.pill,
    borderWidth: 1,
    flexDirection: 'row',
    gap: 8,
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  modeText: { fontSize: 15, fontWeight: '700' },
  balanceCard: { borderRadius: radius.lg, borderWidth: 1, padding: 12 },
  balanceSummary: {
    borderRadius: radius.md,
    flexDirection: 'row',
    justifyContent: 'space-between',
    paddingHorizontal: 16,
    paddingVertical: 18,
  },
  date: { fontSize: 23, fontWeight: '700', marginBottom: 12 },
  outflow: { fontSize: 14 },
  balanceValueBlock: { alignItems: 'flex-end', justifyContent: 'center' },
  balance: { fontSize: 32, fontWeight: '700', letterSpacing: -1.2 },
  balanceLabel: { fontSize: 13, marginTop: 3 },
  chartLabels: { flexDirection: 'row', justifyContent: 'space-between', paddingHorizontal: 4 },
  chartLabel: { fontSize: 13 },
  updated: { fontSize: 13, marginTop: 14, paddingHorizontal: 4 },
  insightCard: { borderRadius: radius.lg, borderWidth: 1, marginTop: spacing.md, padding: spacing.lg },
  insightIcon: {
    alignItems: 'center',
    borderRadius: 14,
    height: 46,
    justifyContent: 'center',
    marginBottom: spacing.sm,
    width: 46,
  },
  insightTitle: { fontSize: 18, fontWeight: '700', lineHeight: 24 },
  insightMessage: { fontSize: 14, lineHeight: 21, marginTop: 5 },
  insightButton: { alignItems: 'center', borderRadius: radius.pill, marginTop: spacing.md, paddingVertical: 13 },
  insightButtonText: { color: colors.white, fontSize: 15, fontWeight: '700' },
  rangeToggle: { borderRadius: radius.pill, flexDirection: 'row', marginTop: spacing.lg, padding: 4 },
  rangeOption: { alignItems: 'center', borderRadius: radius.pill, flex: 1, paddingVertical: 10 },
  rangeText: { fontSize: 14, fontWeight: '700' },
  card: { borderRadius: radius.md, borderWidth: 1, paddingHorizontal: spacing.md },
});
