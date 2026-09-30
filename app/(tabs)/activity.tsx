import { useMemo, useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAccounts, useCategories, useDeleteTransaction, useTransactions } from '@/data/hooks';
import type { TransactionType } from '@/domain/types';
import { formatCurrency } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { AnimatedEntry, EmptyState, FloatingAdd, Header, Pill, Screen, TransactionRow } from '@/components/ui';
import { useAppStore } from '@/store/app-store';

export default function ActivityScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const currency = useAppStore((state) => state.currency);
  const [search, setSearch] = useState('');
  const [type, setType] = useState<TransactionType | 'all'>('all');
  const [sort, setSort] = useState<'date_desc' | 'date_asc' | 'amount_desc' | 'amount_asc'>('date_desc');
  const transactions = useTransactions({ search, type, sort });
  const accounts = useAccounts();
  const categories = useCategories();
  const deleteTransaction = useDeleteTransaction();
  const accountById = useMemo(
    () => new Map((accounts.data ?? []).map((account) => [account.id, account])),
    [accounts.data],
  );
  const categoryById = useMemo(
    () => new Map((categories.data ?? []).map((category) => [category.id, category])),
    [categories.data],
  );
  const confirmDelete = (id: string, title: string) =>
    Alert.alert('Delete transaction?', `${title} will be removed and its account balance recalculated.`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Delete', style: 'destructive', onPress: () => deleteTransaction.mutate(id) },
    ]);

  return (
    <Screen>
      <Header eyebrow="Ledger" title="Activity" action="Add" onAction={() => router.push('/transaction/new')} />
      <View style={[styles.search, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        <MaterialIcons name="search" size={20} color={theme.inkMuted} />
        <TextInput
          value={search}
          onChangeText={setSearch}
          placeholder="Search transactions"
          placeholderTextColor={theme.inkMuted}
          style={[styles.searchInput, { color: theme.ink }]}
          returnKeyType="search"
        />
      </View>
      <View style={styles.pills}>
        <Pill label="All" selected={type === 'all'} onPress={() => setType('all')} />
        <Pill label="Income" tone="income" selected={type === 'income'} onPress={() => setType('income')} />
        <Pill label="Expense" tone="expense" selected={type === 'expense'} onPress={() => setType('expense')} />
        <Pill label="Transfer" tone="transfer" selected={type === 'transfer'} onPress={() => setType('transfer')} />
        <Pill label="Adjustment" selected={type === 'adjustment'} onPress={() => setType('adjustment')} />
      </View>
      <View style={styles.sortRow}>
        <Text style={[styles.resultText, { color: theme.inkMuted }]}>{transactions.data?.length ?? 0} entries</Text>
        <Pressable
          onPress={() => setSort(sort === 'date_desc' ? 'amount_desc' : 'date_desc')}
          style={[styles.sortButton, { backgroundColor: theme.surfaceAlt }]}
        >
          <MaterialIcons name="sort" size={16} color={theme.primary} />
          <Text style={[styles.sortText, { color: theme.primary }]}>
            {sort === 'amount_desc' ? 'Highest amount' : 'Newest first'}
          </Text>
        </Pressable>
      </View>
      {transactions.data?.length ? (
        <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          {transactions.data.map((transaction, index) => (
            <AnimatedEntry key={transaction.id} delay={index * 35}>
              <TransactionRow
                transaction={transaction}
                account={accountById.get(transaction.accountId ?? '')}
                onPress={() =>
                  Alert.alert(
                    transaction.title,
                    `${formatCurrency(transaction.amount, currency)} · ${categoryById.get(transaction.categoryId)?.name ?? 'Uncategorised'}${transaction.notes ? `\n\n${transaction.notes}` : ''}`,
                    [
                      { text: 'Close', style: 'cancel' },
                      { text: 'Edit', onPress: () => router.push(`/transaction/new?id=${transaction.id}`) },
                      {
                        text: 'Delete',
                        style: 'destructive',
                        onPress: () => confirmDelete(transaction.id, transaction.title),
                      },
                    ],
                  )
                }
              />
            </AnimatedEntry>
          ))}
        </View>
      ) : (
        <EmptyState
          icon="receipt-long"
          title="Nothing here yet"
          message={
            search
              ? 'Try another search or clear your filters.'
              : 'Your activity will appear here as soon as you add a transaction.'
          }
          action="Add transaction"
          onAction={() => router.push('/transaction/new')}
        />
      )}
      <FloatingAdd />
    </Screen>
  );
}

const styles = StyleSheet.create({
  search: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 9,
    borderWidth: 1,
    borderRadius: radius.md,
    paddingHorizontal: spacing.md,
    height: 48,
  },
  searchInput: { flex: 1, fontSize: 14 },
  pills: { flexDirection: 'row', flexWrap: 'wrap', rowGap: 8, marginTop: spacing.md },
  sortRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.lg,
    marginBottom: spacing.sm,
  },
  resultText: { fontSize: 12, fontWeight: '700' },
  sortButton: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingHorizontal: 10,
    paddingVertical: 7,
    borderRadius: radius.pill,
  },
  sortText: { fontSize: 11, fontWeight: '800' },
  card: { borderRadius: radius.md, borderWidth: 1, paddingHorizontal: spacing.md },
});
