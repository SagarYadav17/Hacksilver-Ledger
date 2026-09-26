import { useMemo, useState } from 'react';
import { Alert, Pressable, StyleSheet, Text, TextInput, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useArchiveCategory, useCategories, useCreateCategory, useMergeCategories } from '@/data/hooks';
import type { Category } from '@/domain/types';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { Header, Pill, Screen } from '@/components/ui';

export default function CategoriesScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const [archived, setArchived] = useState(false);
  const [name, setName] = useState('');
  const categories = useCategories(archived);
  const create = useCreateCategory();
  const archive = useArchiveCategory();
  const merge = useMergeCategories();
  const visible = useMemo(() => categories.data ?? [], [categories.data]);
  const add = () => {
    if (!name.trim()) return;
    create.mutate({ name: name.trim(), type: 'expense', color: '#2E6B57' }, { onSuccess: () => setName('') });
  };
  const mergeItem = (source: Category) => {
    const target = visible.find((item) => item.id !== source.id && item.type === source.type);
    if (!target) {
      Alert.alert('Nothing to merge into', 'Create another category of the same type first.');
      return;
    }
    Alert.alert('Merge category?', `Move ${source.name} entries into ${target.name} and archive ${source.name}?`, [
      { text: 'Cancel', style: 'cancel' },
      { text: 'Merge', onPress: () => merge.mutate({ sourceId: source.id, targetId: target.id }) },
    ]);
  };
  return (
    <Screen>
      <Header eyebrow="Organise" title="Categories" action="Done" onAction={() => router.back()} />
      <View style={styles.tabs}>
        <Pill label="Active" selected={!archived} onPress={() => setArchived(false)} />
        <Pill label="Archived" selected={archived} onPress={() => setArchived(true)} />
      </View>
      <View style={[styles.add, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        <TextInput
          value={name}
          onChangeText={setName}
          placeholder="New expense category"
          placeholderTextColor={theme.inkMuted}
          style={[styles.addInput, { color: theme.ink }]}
        />
        <Pressable onPress={add} style={[styles.addButton, { backgroundColor: theme.primary }]}>
          <MaterialIcons name="add" size={19} color={theme.white} />
        </Pressable>
      </View>
      <View style={[styles.card, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        {visible.map((item) => (
          <View key={item.id} style={styles.row}>
            <View style={[styles.dot, { backgroundColor: item.color }]} />
            <View style={styles.copy}>
              <Text style={[styles.itemName, { color: theme.ink }]}>{item.name}</Text>
              <Text style={[styles.itemMeta, { color: theme.inkMuted }]}>
                {item.type} {item.isCustom ? '· custom' : '· default'}
              </Text>
            </View>
            <Pressable onPress={() => mergeItem(item)} hitSlop={8}>
              <MaterialIcons name="merge-type" size={20} color={theme.inkMuted} />
            </Pressable>
            <Pressable
              onPress={() => archive.mutate({ id: item.id, archived: !archived })}
              hitSlop={8}
              style={{ marginLeft: 14 }}
            >
              <MaterialIcons name={archived ? 'unarchive' : 'archive'} size={20} color={theme.inkMuted} />
            </Pressable>
          </View>
        ))}
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  tabs: { flexDirection: 'row', marginBottom: spacing.md },
  add: {
    flexDirection: 'row',
    alignItems: 'center',
    borderWidth: 1,
    borderRadius: radius.md,
    paddingLeft: spacing.md,
    marginBottom: spacing.md,
  },
  addInput: { flex: 1, fontSize: 14, paddingVertical: 13 },
  addButton: { width: 44, height: 44, borderRadius: 13, justifyContent: 'center', alignItems: 'center', margin: 3 },
  card: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 13,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: '#DEE5DF',
  },
  dot: { width: 12, height: 12, borderRadius: 6, marginRight: 12 },
  copy: { flex: 1 },
  itemName: { fontSize: 14, fontWeight: '800' },
  itemMeta: { fontSize: 11, marginTop: 3 },
});
