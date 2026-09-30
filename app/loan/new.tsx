import { useState } from 'react';
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
import { useRouter } from 'expo-router';
import { useCreateLoan } from '@/data/hooks';
import type { LoanType } from '@/domain/types';
import { calculateEmi } from '@/domain/loan';
import { formatCurrency } from '@/lib/format';
import { useAppStore } from '@/store/app-store';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Pill } from '@/components/ui';

export default function NewLoanScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const create = useCreateLoan();
  const [title, setTitle] = useState('');
  const [amount, setAmount] = useState('');
  const [interest, setInterest] = useState('');
  const [tenure, setTenure] = useState('12');
  const [emi, setEmi] = useState('');
  const [type, setType] = useState<LoanType>('taken');
  const currency = useAppStore((state) => state.currency);
  const principal = parseNumber(amount);
  const rate = interest.trim() ? parseNumber(interest) : 0;
  const months = parseNumber(tenure);
  const validPrincipal = Number.isFinite(principal) && principal > 0;
  const validRate = Number.isFinite(rate) && rate >= 0 && rate <= 100;
  const validMonths = Number.isInteger(months) && months >= 1 && months <= 600;
  const computedEmi = validPrincipal && validRate && validMonths ? calculateEmi(principal, rate, months) : null;
  const save = () => {
    const customEmi = emi.trim() ? parseNumber(emi) : null;
    if (!title.trim() || !validPrincipal) {
      Alert.alert('Complete the loan', 'Add a title and a positive amount.');
      return;
    }
    if (!validRate || !validMonths) {
      Alert.alert('Check the terms', 'Interest must be 0–100% and tenure a whole number of 1–600 months.');
      return;
    }
    if (customEmi !== null && !(Number.isFinite(customEmi) && customEmi > 0)) {
      Alert.alert('Check the EMI', 'Enter a positive EMI or leave it blank to auto-calculate.');
      return;
    }
    const emiValue = customEmi ?? computedEmi ?? 0;
    create.mutate(
      {
        title: title.trim(),
        amount: principal,
        interestRate: rate,
        tenureMonths: months,
        type,
        startDate: new Date().toISOString(),
        emiAmount: emiValue,
        notes: null,
      },
      { onSuccess: () => router.back(), onError: (error) => Alert.alert('Could not save', error.message) },
    );
  };
  return (
    <KeyboardAvoidingView
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
      style={[styles.screen, { backgroundColor: theme.canvas }]}
    >
      <View style={styles.top}>
        <Pressable onPress={() => router.back()}>
          <MaterialIcons name="close" size={25} color={theme.ink} />
        </Pressable>
        <Text style={[styles.title, { color: theme.ink }]}>New loan</Text>
        <Pressable onPress={save}>
          <Text style={[styles.save, { color: theme.primary }]}>Save</Text>
        </Pressable>
      </View>
      <ScrollView contentContainerStyle={styles.content}>
        <Text style={[styles.label, { color: theme.inkMuted }]}>DIRECTION</Text>
        <View style={styles.row}>
          <Pill label="I borrowed" selected={type === 'taken'} onPress={() => setType('taken')} />
          <Pill label="I lent" selected={type === 'given'} onPress={() => setType('given')} />
        </View>
        <Text style={[styles.label, { color: theme.inkMuted }]}>LOAN NAME</Text>
        <TextInput
          value={title}
          onChangeText={setTitle}
          placeholder="e.g. Home renovation"
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
          autoFocus
        />
        <Text style={[styles.label, { color: theme.inkMuted }]}>PRINCIPAL</Text>
        <TextInput
          value={amount}
          onChangeText={setAmount}
          keyboardType="decimal-pad"
          placeholder="0.00"
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
        />
        <View style={styles.two}>
          <View style={styles.half}>
            <Text style={[styles.label, { color: theme.inkMuted }]}>INTEREST %</Text>
            <TextInput
              value={interest}
              onChangeText={setInterest}
              keyboardType="decimal-pad"
              placeholder="0"
              placeholderTextColor={theme.inkMuted}
              style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
            />
          </View>
          <View style={styles.half}>
            <Text style={[styles.label, { color: theme.inkMuted }]}>TENURE (MONTHS)</Text>
            <TextInput
              value={tenure}
              onChangeText={setTenure}
              keyboardType="number-pad"
              placeholder="12"
              placeholderTextColor={theme.inkMuted}
              style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
            />
          </View>
        </View>
        <Text style={[styles.label, { color: theme.inkMuted }]}>MONTHLY EMI (OPTIONAL)</Text>
        <TextInput
          value={emi}
          onChangeText={setEmi}
          keyboardType="decimal-pad"
          placeholder={computedEmi !== null ? String(computedEmi) : 'Auto-calculated'}
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { backgroundColor: theme.surface, borderColor: theme.line, color: theme.ink }]}
        />
        {computedEmi !== null && (
          <Text style={[styles.hint, { color: theme.inkMuted }]}>
            Calculated EMI: {formatCurrency(computedEmi, currency)} / month
            {emi.trim() ? ' (overridden by your value)' : ''}
          </Text>
        )}
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
  content: { padding: spacing.md, paddingBottom: 40 },
  label: { fontSize: 11, letterSpacing: 1.2, fontWeight: '800', marginTop: spacing.lg, marginBottom: spacing.sm },
  row: { flexDirection: 'row' },
  input: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, fontSize: 15 },
  two: { flexDirection: 'row', gap: spacing.sm },
  half: { flex: 1 },
  hint: { fontSize: 12, marginTop: spacing.sm },
});

function parseNumber(value: string): number {
  const cleaned = value.replace(/,/g, '').trim();
  return cleaned ? Number(cleaned) : Number.NaN;
}
