import { useRouter } from 'expo-router';
import { StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useAccounts } from '@/data/hooks';
import { formatCurrency } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { AccountRow, AnimatedEntry, EmptyState, Header, LoadingBlock, Screen } from '@/components/ui';
import { useAppStore } from '@/store/app-store';

export default function AccountsScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const currency = useAppStore((state) => state.currency);
  const accounts = useAccounts();
  const total = accounts.data?.reduce((sum, account) => sum + account.balance, 0) ?? 0;
  return (
    <Screen>
      <Header eyebrow="Your money" title="Accounts" action="Add account" onAction={() => router.push('/account/new')} />
      {accounts.isLoading ? (
        <LoadingBlock />
      ) : (
        <View style={[styles.totalCard, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          <View style={styles.totalTop}>
            <Text style={[styles.totalLabel, { color: theme.inkMuted }]}>COMBINED BALANCE</Text>
            <MaterialIcons name="account-balance-wallet" size={20} color={theme.primary} />
          </View>
          <Text style={[styles.total, { color: theme.ink }]}>{formatCurrency(total, currency, hidden)}</Text>
          <Text style={[styles.totalHint, { color: theme.inkMuted }]}>
            {accounts.data?.length ?? 0} active accounts
          </Text>
        </View>
      )}
      {accounts.data?.length ? (
        <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          {accounts.data.map((account, index) => (
            <AnimatedEntry key={account.id} delay={index * 45}>
              <AccountRow account={account} onPress={() => router.push(`/account/${account.id}`)} />
            </AnimatedEntry>
          ))}
        </View>
      ) : (
        <EmptyState
          icon="account-balance-wallet"
          title="Create your money map"
          message="Add cash, bank, and card accounts so every transaction stays connected to a real balance."
          action="Add account"
          onAction={() => router.push('/account/new')}
        />
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  totalCard: { borderWidth: 1, borderRadius: radius.lg, padding: spacing.lg, marginBottom: spacing.md },
  totalTop: { flexDirection: 'row', justifyContent: 'space-between' },
  totalLabel: { fontSize: 11, letterSpacing: 1.2, fontWeight: '800' },
  total: { fontSize: 34, fontWeight: '800', letterSpacing: -1.3, marginVertical: 16 },
  totalHint: { fontSize: 12 },
  card: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
});
