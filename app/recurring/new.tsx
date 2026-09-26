import { useEffect, useMemo, useState } from 'react';
import {
  Alert,
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useLocalSearchParams, useRouter } from 'expo-router';
import {
  useAccounts,
  useCategories,
  useCreateRecurring,
  useRecurringTransactions,
  useUpdateRecurring,
} from '@/data/hooks';
import type { Frequency, TransactionType } from '@/domain/types';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Pill } from '@/components/ui';

export default function NewRecurringScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { colors: theme } = useAppTheme();
  const categories = useCategories();
  const accounts = useAccounts();
  const recurring = useRecurringTransactions();
  const create = useCreateRecurring();
  const update = useUpdateRecurring();
  const existing = useMemo(() => recurring.data?.find((item) => item.id === id), [recurring.data, id]);
  const [title, setTitle] = useState('');
  const [amount, setAmount] = useState('');
  const [type, setType] = useState<Exclude<TransactionType, 'adjustment'>>('expense');
  const [frequency, setFrequency] = useState<Frequency>('monthly');
  const [categoryId, setCategoryId] = useState('');
  const [accountId, setAccountId] = useState<string | null>(null);

  useEffect(() => {
    if (!existing) return;
    setTitle(existing.title);
    setAmount(String(existing.amount));
    setType(existing.type);
    setFrequency(existing.frequency);
    setCategoryId(existing.categoryId);
    setAccountId(existing.accountId ?? null);
  }, [existing]);

  useEffect(() => {
    if (!categoryId && categories.data?.length)
      setCategoryId(categories.data.find((item) => item.type === type)?.id ?? '');
  }, [categories.data, categoryId, type]);

  const save = () => {
    const value = Number(amount.replace(/,/g, ''));
    const category = categoryId || categories.data?.find((item) => item.type === type)?.id;
    if (!title.trim() || !Number.isFinite(value) || value <= 0 || !category) {
      Alert.alert('Complete the recurring entry', 'Add a title, amount, and category.');
      return;
    }
    if (existing) {
      update.mutate(
        {
          id: existing.id,
          patch: { title: title.trim(), amount: value, type, categoryId: category, accountId, frequency },
        },
        { onSuccess: () => router.back(), onError: (error) => Alert.alert('Could not save', error.message) },
      );
    } else {
      create.mutate(
        {
          title: title.trim(),
          amount: value,
          type,
          categoryId: category,
          accountId,
          frequency,
          startDate: new Date().toISOString(),
          nextDueDate: new Date().toISOString(),
          isActive: true,
          notes: null,
        },
        { onSuccess: () => router.back(), onError: (error) => Alert.alert('Could not save', error.message) },
      );
    }
  };

  const matchingCategories = categories.data?.filter((item) => item.type === type) ?? [];
  const pending = create.isPending || update.isPending;
  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={[styles.screen, { backgroundColor: theme.canvas }]}
    >
      <View style={styles.top}>
        <Pressable onPress={() => router.back()}>
          <MaterialIcons name="close" size={25} color={theme.ink} />
        </Pressable>
        <Text style={[styles.title, { color: theme.ink }]}>{existing ? 'Edit recurring' : 'New recurring'}</Text>
        <Pressable onPress={save} disabled={pending}>
          <Text style={[styles.save, { color: theme.primary }]}>{pending ? 'Saving' : 'Save'}</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={[styles.label, { color: theme.inkMuted }]}>TYPE</Text>
        <View style={styles.row}>
          {(['expense', 'income'] as const).map((value) => (
            <Pill
              key={value}
              label={value[0].toUpperCase() + value.slice(1)}
              tone={value}
              selected={type === value}
              onPress={() => setType(value)}
            />
          ))}
        </View>
        <Text style={[styles.label, { color: theme.inkMuted }]}>TITLE</Text>
        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="e.g. Rent"
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
          autoFocus={!existing}
        />
        <Text style={[styles.label, { color: theme.inkMuted }]}>AMOUNT</Text>
        <TextInput
          value={amount}
          onChangeText={setAmount}
          keyboardType="decimal-pad"
          placeholder="0.00"
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
        />
        <Text style={[styles.label, { color: theme.inkMuted }]}>FREQUENCY</Text>
        <View style={styles.row}>
          {(['daily', 'monthly', 'quarterly', 'yearly'] as const).map((value) => (
            <Pill
              key={value}
              label={value[0].toUpperCase() + value.slice(1)}
              selected={frequency === value}
              onPress={() => setFrequency(value)}
            />
          ))}
        </View>
        <Text style={[styles.label, { color: theme.inkMuted }]}>CATEGORY</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false}>
          {matchingCategories.map((item) => (
            <Pill
              key={item.id}
              label={item.name}
              selected={categoryId === item.id}
              onPress={() => setCategoryId(item.id)}
            />
          ))}
        </ScrollView>
        {accounts.data?.length ? (
          <>
            <Text style={[styles.label, { color: theme.inkMuted }]}>ACCOUNT</Text>
            <ScrollView horizontal showsHorizontalScrollIndicator={false}>
              <Pill label="No account" selected={!accountId} onPress={() => setAccountId(null)} />
              {accounts.data.map((item) => (
                <Pill
                  key={item.id}
                  label={item.name}
                  selected={accountId === item.id}
                  onPress={() => setAccountId(item.id)}
                />
              ))}
            </ScrollView>
          </>
        ) : null}
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  top: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    padding: spacing.md,
    paddingTop: 18,
  },
  title: { fontSize: 17, fontWeight: '800' },
  save: { fontSize: 14, fontWeight: '800' },
  content: { padding: spacing.md, paddingBottom: 50 },
  label: { fontSize: 11, letterSpacing: 1.2, fontWeight: '800', marginTop: spacing.lg, marginBottom: spacing.sm },
  row: { flexDirection: 'row' },
  input: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, fontSize: 15 },
});
