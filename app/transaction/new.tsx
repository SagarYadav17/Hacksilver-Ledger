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
import { useAccounts, useCategories, useCreateTransaction, useTransactions, useUpdateTransaction } from '@/data/hooks';
import type { TransactionInput, TransactionType } from '@/domain/types';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Pill } from '@/components/ui';

export default function TransactionFormScreen() {
  const router = useRouter();
  const { id } = useLocalSearchParams<{ id?: string }>();
  const { colors: theme } = useAppTheme();
  const accounts = useAccounts();
  const categories = useCategories();
  const transactions = useTransactions();
  const create = useCreateTransaction();
  const update = useUpdateTransaction();
  const existing = useMemo(() => transactions.data?.find((item) => item.id === id), [transactions.data, id]);
  const [title, setTitle] = useState('');
  const [amount, setAmount] = useState('');
  const [type, setType] = useState<TransactionType>('expense');
  const [categoryId, setCategoryId] = useState('');
  const [accountId, setAccountId] = useState<string | null>(null);
  const [transferAccountId, setTransferAccountId] = useState<string | null>(null);
  const [notes, setNotes] = useState('');

  useEffect(() => {
    if (!existing) return;
    setTitle(existing.title);
    setAmount(String(existing.amount));
    setType(existing.type);
    setCategoryId(existing.categoryId);
    setAccountId(existing.accountId ?? null);
    setTransferAccountId(existing.transferAccountId ?? null);
    setNotes(existing.notes ?? '');
  }, [existing]);

  useEffect(() => {
    if (!categoryId && categories.data?.length) {
      setCategoryId(categories.data.find((item) => item.type === type)?.id ?? categories.data[0].id);
    }
    if (type !== 'transfer') setTransferAccountId(null);
  }, [categories.data, categoryId, type]);

  const submit = () => {
    const numericAmount = Number(amount.replace(/,/g, ''));
    if (!title.trim() || !Number.isFinite(numericAmount) || numericAmount <= 0 || !categoryId) {
      Alert.alert('Almost there', 'Add a title, a positive amount, and a category.');
      return;
    }
    if (type === 'transfer' && (!accountId || !transferAccountId || accountId === transferAccountId)) {
      Alert.alert('Choose both accounts', 'Transfers need different source and destination accounts.');
      return;
    }
    const input: TransactionInput = {
      title: title.trim(),
      amount: numericAmount,
      date: existing?.date ?? new Date().toISOString(),
      type,
      categoryId,
      accountId,
      transferAccountId: type === 'transfer' ? transferAccountId : null,
      notes: notes.trim() || null,
    };
    if (existing) {
      update.mutate(
        { id: existing.id, input },
        { onSuccess: () => router.back(), onError: (error) => Alert.alert('Could not save', error.message) },
      );
    } else {
      create.mutate(input, {
        onSuccess: () => router.back(),
        onError: (error) => Alert.alert('Could not save', error.message),
      });
    }
  };

  const availableCategories =
    categories.data?.filter((item) => (type === 'transfer' ? item.type === 'transfer' : item.type === type)) ?? [];
  const availableDestinationAccounts = accounts.data?.filter((item) => item.id !== accountId) ?? [];

  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={[styles.screen, { backgroundColor: theme.canvas }]}
    >
      <View style={styles.topBar}>
        <Pressable onPress={() => router.back()} hitSlop={10}>
          <MaterialIcons name="close" size={25} color={theme.ink} />
        </Pressable>
        <Text style={[styles.formTitle, { color: theme.ink }]}>
          {existing ? 'Edit transaction' : 'New transaction'}
        </Text>
        <Pressable onPress={submit} disabled={create.isPending || update.isPending}>
          <Text style={[styles.save, { color: theme.primary }]}>
            {create.isPending || update.isPending ? 'Saving' : 'Save'}
          </Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.content} keyboardShouldPersistTaps="handled">
        <Text style={[styles.label, { color: theme.inkMuted }]}>TYPE</Text>
        <View style={styles.typeRow}>
          {(['expense', 'income', 'transfer'] as const).map((value) => (
            <Pill
              key={value}
              label={value[0].toUpperCase() + value.slice(1)}
              tone={value}
              selected={type === value}
              onPress={() => setType(value)}
            />
          ))}
        </View>
        <Text style={[styles.label, { color: theme.inkMuted }]}>AMOUNT</Text>
        <View style={[styles.amountField, { backgroundColor: theme.surface, borderColor: theme.line }]}>
          <Text style={[styles.currency, { color: theme.inkMuted }]}>₹</Text>
          <TextInput
            value={amount}
            onChangeText={setAmount}
            keyboardType="decimal-pad"
            placeholder="0.00"
            placeholderTextColor={theme.inkMuted}
            style={[styles.amountInput, { color: theme.ink }]}
          />
        </View>
        <Text style={[styles.label, { color: theme.inkMuted }]}>WHAT WAS THIS FOR?</Text>
        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="e.g. Weekly groceries"
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
          autoFocus={!existing}
        />
        <Text style={[styles.label, { color: theme.inkMuted }]}>CATEGORY</Text>
        <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={styles.horizontalPills}>
          {availableCategories.map((item) => (
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
            <Text style={[styles.label, { color: theme.inkMuted }]}>
              {type === 'transfer' ? 'FROM ACCOUNT' : 'ACCOUNT'}
            </Text>
            <ScrollView
              horizontal
              showsHorizontalScrollIndicator={false}
              contentContainerStyle={styles.horizontalPills}
            >
              <Pill label="No account" selected={!accountId} onPress={() => setAccountId(null)} />
              {accounts.data.map((item) => (
                <Pill
                  key={item.id}
                  label={item.name}
                  selected={accountId === item.id}
                  onPress={() => {
                    setAccountId(item.id);
                    if (transferAccountId === item.id) setTransferAccountId(null);
                  }}
                />
              ))}
            </ScrollView>
            {type === 'transfer' && (
              <>
                <Text style={[styles.label, { color: theme.inkMuted }]}>TO ACCOUNT</Text>
                <ScrollView
                  horizontal
                  showsHorizontalScrollIndicator={false}
                  contentContainerStyle={styles.horizontalPills}
                >
                  {availableDestinationAccounts.map((item) => (
                    <Pill
                      key={item.id}
                      label={item.name}
                      selected={transferAccountId === item.id}
                      onPress={() => setTransferAccountId(item.id)}
                    />
                  ))}
                </ScrollView>
              </>
            )}
          </>
        ) : (
          <View style={[styles.notice, { backgroundColor: theme.warningSoft }]}>
            <MaterialIcons name="info-outline" color={theme.warning} size={18} />
            <Text style={[styles.noticeText, { color: theme.warning }]}>Add an account to keep balances accurate.</Text>
          </View>
        )}
        <Text style={[styles.label, { color: theme.inkMuted }]}>NOTE</Text>
        <TextInput
          value={notes}
          onChangeText={setNotes}
          placeholder="Optional note"
          placeholderTextColor={theme.inkMuted}
          style={[
            styles.input,
            styles.notes,
            { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink },
          ]}
          multiline
        />
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1 },
  topBar: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: spacing.md,
    paddingTop: 18,
    paddingBottom: spacing.md,
  },
  formTitle: { fontSize: 17, fontWeight: '800' },
  save: { fontSize: 14, fontWeight: '800' },
  content: { padding: spacing.md, paddingBottom: 50 },
  label: { fontSize: 11, letterSpacing: 1.2, fontWeight: '800', marginTop: spacing.lg, marginBottom: spacing.sm },
  typeRow: { flexDirection: 'row' },
  amountField: {
    borderWidth: 1,
    borderRadius: radius.md,
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: spacing.md,
  },
  currency: { fontSize: 24, fontWeight: '700' },
  amountInput: { flex: 1, fontSize: 32, fontWeight: '800', paddingVertical: 12, marginLeft: 8 },
  input: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, fontSize: 15 },
  horizontalPills: { paddingBottom: 2 },
  notice: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    borderRadius: radius.sm,
    padding: spacing.sm,
    marginTop: spacing.md,
  },
  noticeText: { flex: 1, fontSize: 12, fontWeight: '600' },
  notes: { minHeight: 92, textAlignVertical: 'top' },
});
