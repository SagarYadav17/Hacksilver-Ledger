import { useState } from 'react';
import { Alert, KeyboardAvoidingView, Platform, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useCreateAccount } from '@/data/hooks';
import type { AccountType } from '@/domain/types';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Pill } from '@/components/ui';

export default function NewAccountScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const create = useCreateAccount();
  const [name, setName] = useState('');
  const [type, setType] = useState<AccountType>('bank');
  const save = () => {
    if (!name.trim()) {
      Alert.alert('Name your account', 'Add a name like Main bank or Cash wallet.');
      return;
    }
    create.mutate(
      { name: name.trim(), type },
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
        <Text style={[styles.title, { color: theme.ink }]}>New account</Text>
        <Pressable onPress={save}>
          <Text style={[styles.save, { color: theme.primary }]}>Save</Text>
        </Pressable>
      </View>
      <View style={styles.content}>
        <Text style={[styles.label, { color: theme.inkMuted }]}>ACCOUNT NAME</Text>
        <TextInput
          autoFocus
          value={name}
          onChangeText={setName}
          placeholder="e.g. Main bank account"
          placeholderTextColor={theme.inkMuted}
          style={[styles.input, { color: theme.ink, backgroundColor: theme.surface, borderColor: theme.line }]}
        />
        <Text style={[styles.label, { color: theme.inkMuted }]}>ACCOUNT TYPE</Text>
        <View style={styles.pills}>
          {(['bank', 'cash', 'credit_card', 'other'] as const).map((value) => (
            <Pill
              key={value}
              label={value === 'credit_card' ? 'Credit card' : value[0].toUpperCase() + value.slice(1)}
              selected={type === value}
              onPress={() => setType(value)}
            />
          ))}
        </View>
      </View>
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
  content: { padding: spacing.md },
  label: { fontSize: 11, letterSpacing: 1.2, fontWeight: '800', marginTop: spacing.lg, marginBottom: spacing.sm },
  input: { borderWidth: 1, borderRadius: radius.md, padding: spacing.md, fontSize: 15 },
  pills: { flexDirection: 'row', flexWrap: 'wrap' },
});
