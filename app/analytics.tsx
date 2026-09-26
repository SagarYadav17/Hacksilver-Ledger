import { useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useCategories, useTransactions } from '@/data/hooks';
import { formatCurrency } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Header, MetricCard, Pill, Screen } from '@/components/ui';
import { useAppStore } from '@/store/app-store';

export default function AnalyticsScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const currency = useAppStore((state) => state.currency);
  const [compare, setCompare] = useState(false);
  const transactions = useTransactions({ sort: 'date_desc' });
  const categories = useCategories();
  const currentMonth = new Date().getMonth();
  const currentYear = new Date().getFullYear();
  const current = (transactions.data ?? []).filter((item) => {
    const date = new Date(item.date);
    return date.getMonth() === currentMonth && date.getFullYear() === currentYear;
  });
  const previous = (transactions.data ?? []).filter((item) => {
    const date = new Date(item.date);
    const prev = new Date(currentYear, currentMonth - 1, 1);
    return date.getMonth() === prev.getMonth() && date.getFullYear() === prev.getFullYear();
  });
  const income = current.filter((item) => item.type === 'income').reduce((sum, item) => sum + item.amount, 0);
  const expenses = current.filter((item) => item.type === 'expense').reduce((sum, item) => sum + item.amount, 0);
  const previousExpenses = previous
    .filter((item) => item.type === 'expense')
    .reduce((sum, item) => sum + item.amount, 0);
  const categoryBars = useMemo(() => {
    const totals = new Map<string, number>();
    current
      .filter((item) => item.type === 'expense')
      .forEach((item) => totals.set(item.categoryId, (totals.get(item.categoryId) ?? 0) + item.amount));
    return [...totals.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 5)
      .map(([id, total]) => ({ name: categories.data?.find((item) => item.id === id)?.name ?? 'Other', total }));
  }, [current, categories.data]);
  const max = Math.max(1, ...categoryBars.map((item) => item.total));
  return (
    <Screen>
      <View style={styles.top}>
        <Pressable onPress={() => router.back()}>
          <MaterialIcons name="arrow-back" size={24} color={theme.ink} />
        </Pressable>
        <Header eyebrow="Patterns" title="Analytics" />
        <View style={{ width: 24 }} />
      </View>
      <View style={styles.toggle}>
        <Pill label="This month" selected={!compare} onPress={() => setCompare(false)} />
        <Pill label="Compare last month" selected={compare} onPress={() => setCompare(true)} />
      </View>
      <View style={styles.grid}>
        <MetricCard label="Income" value={formatCurrency(income, currency)} tone="positive" />
        <MetricCard label="Spending" value={formatCurrency(expenses, currency)} tone="negative" />
      </View>
      <View style={[styles.insight, { backgroundColor: theme.primarySoft }]}>
        <MaterialIcons name="auto-graph" size={20} color={theme.primary} />
        <Text style={[styles.insightText, { color: theme.ink }]}>
          {compare
            ? `${expenses >= previousExpenses ? 'Up' : 'Down'} ${formatCurrency(Math.abs(expenses - previousExpenses), currency)} from last month`
            : income > expenses
              ? 'You are spending less than you earn this month.'
              : 'Add income and expenses to see your savings trend.'}
        </Text>
      </View>
      <Text style={[styles.section, { color: theme.ink }]}>Where your money goes</Text>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        {categoryBars.length ? (
          categoryBars.map((item) => (
            <View key={item.name} style={styles.barRow}>
              <View style={styles.barLabel}>
                <Text style={[styles.name, { color: theme.ink }]}>{item.name}</Text>
                <Text style={[styles.value, { color: theme.inkMuted }]}>{formatCurrency(item.total, currency)}</Text>
              </View>
              <View style={[styles.track, { backgroundColor: theme.surfaceAlt }]}>
                <View style={[styles.bar, { backgroundColor: theme.primary, width: `${(item.total / max) * 100}%` }]} />
              </View>
            </View>
          ))
        ) : (
          <Text style={[styles.empty, { color: theme.inkMuted }]}>
            Your category breakdown will appear after your first expense.
          </Text>
        )}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  top: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between', paddingTop: spacing.md },
  toggle: { flexDirection: 'row', marginBottom: spacing.md },
  grid: { flexDirection: 'row', gap: spacing.sm },
  insight: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    borderRadius: radius.md,
    padding: spacing.md,
    marginTop: spacing.md,
  },
  insightText: { flex: 1, fontSize: 13, lineHeight: 19, fontWeight: '700' },
  section: { fontSize: 18, fontWeight: '800', marginTop: spacing.xl, marginBottom: spacing.sm },
  card: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md },
  barRow: { marginVertical: 8 },
  barLabel: { flexDirection: 'row', justifyContent: 'space-between', marginBottom: 7 },
  name: { fontSize: 13, fontWeight: '700' },
  value: { fontSize: 12, fontWeight: '700' },
  track: { height: 9, borderRadius: 5, overflow: 'hidden' },
  bar: { height: 9, borderRadius: 5 },
  empty: { fontSize: 13, lineHeight: 19, paddingVertical: 12 },
});
