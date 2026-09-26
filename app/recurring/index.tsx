import { Pressable, StyleSheet, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useRecurringTransactions, useToggleRecurring } from '@/data/hooks';
import { formatCurrency, formatDate, titleCase } from '@/lib/format';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { EmptyState, Header, Screen } from '@/components/ui';
import { useAppStore } from '@/store/app-store';

export default function RecurringScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const currency = useAppStore((state) => state.currency);
  const items = useRecurringTransactions();
  const toggle = useToggleRecurring();
  return (
    <Screen>
      <Header eyebrow="Automate" title="Recurring" action="Add" onAction={() => router.push('/recurring/new')} />
      {items.data?.length ? (
        items.data.map((item) => (
          <View key={item.id} style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
            <View style={styles.row}>
              <Pressable
                accessibilityRole="button"
                onPress={() => router.push(`/recurring/new?id=${item.id}`)}
                style={styles.rowMain}
              >
                <View style={[styles.icon, { backgroundColor: item.isActive ? theme.primarySoft : theme.surfaceAlt }]}>
                  <MaterialIcons name="event-repeat" size={20} color={item.isActive ? theme.primary : theme.inkMuted} />
                </View>
                <View style={styles.copy}>
                  <Text style={[styles.title, { color: theme.ink }]}>{item.title}</Text>
                  <Text style={[styles.meta, { color: theme.inkMuted }]}>
                    {formatCurrency(item.amount, currency)} · {titleCase(item.frequency)} · next{' '}
                    {formatDate(item.nextDueDate)}
                  </Text>
                </View>
              </Pressable>
              <Pressable onPress={() => toggle.mutate({ id: item.id, active: !item.isActive })}>
                <Text style={[styles.status, { color: item.isActive ? theme.primary : theme.inkMuted }]}>
                  {item.isActive ? 'Active' : 'Paused'}
                </Text>
              </Pressable>
            </View>
          </View>
        ))
      ) : (
        <EmptyState
          icon="event-repeat"
          title="Make regular money easy"
          message="Set up rent, subscriptions, salary, or any repeating entry once."
          action="Add recurring"
          onAction={() => router.push('/recurring/new')}
        />
      )}
    </Screen>
  );
}

const styles = StyleSheet.create({
  card: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, marginBottom: spacing.sm },
  row: { flexDirection: 'row', alignItems: 'center' },
  rowMain: { flex: 1, flexDirection: 'row', alignItems: 'center' },
  icon: { width: 42, height: 42, borderRadius: 14, justifyContent: 'center', alignItems: 'center', marginRight: 11 },
  copy: { flex: 1 },
  title: { fontSize: 14, fontWeight: '800' },
  meta: { fontSize: 11, marginTop: 4 },
  status: { fontSize: 12, fontWeight: '800' },
});
