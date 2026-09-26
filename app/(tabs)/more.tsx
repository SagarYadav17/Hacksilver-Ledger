import { Pressable, StyleSheet, Switch, Text, View } from 'react-native';
import { MaterialIcons } from '@expo/vector-icons';
import { useRouter } from 'expo-router';
import { useAppStore } from '@/store/app-store';
import { colors, radius, spacing, useAppTheme } from '@/lib/theme';
import { Header, Screen } from '@/components/ui';

const rows = [
  { label: 'Analytics', caption: 'Understand your patterns', icon: 'insights', route: '/analytics' },
  { label: 'Categories', caption: 'Organise your spending', icon: 'category', route: '/categories' },
  { label: 'Recurring transactions', caption: 'Automate regular entries', icon: 'event-repeat', route: '/recurring' },
  { label: 'Sync & backup', caption: 'Your data, wherever you are', icon: 'cloud-sync', route: '/sync-backup' },
  { label: 'Settings', caption: 'Currency, privacy, appearance', icon: 'tune', route: '/settings' },
] as const;

export default function MoreScreen() {
  const router = useRouter();
  const { colors: theme } = useAppTheme();
  const hidden = useAppStore((state) => state.hideBalances);
  const setHidden = useAppStore((state) => state.setHideBalances);
  return (
    <Screen>
      <Header eyebrow="Personalise" title="More" />
      <View style={[styles.privacy, { backgroundColor: theme.ink, borderColor: theme.line }]}>
        <View style={[styles.privacyIcon, { backgroundColor: theme.primary }]}>
          <MaterialIcons name="visibility-off" size={19} color={theme.white} />
        </View>
        <View style={styles.copy}>
          <Text style={[styles.privacyTitle, { color: theme.white }]}>Private mode</Text>
          <Text style={styles.privacyCaption}>Hide balances across the app</Text>
        </View>
        <Switch
          value={hidden}
          onValueChange={setHidden}
          trackColor={{ false: '#52605A', true: theme.primary }}
          thumbColor={theme.white}
        />
      </View>
      <View style={[styles.menu, { backgroundColor: theme.surface, borderColor: theme.line }]}>
        {rows.map((row) => (
          <Pressable key={row.route} onPress={() => router.push(row.route)} style={styles.menuRow}>
            <View style={[styles.menuIcon, { backgroundColor: theme.surfaceAlt }]}>
              <MaterialIcons name={row.icon} size={20} color={theme.primary} />
            </View>
            <View style={styles.copy}>
              <Text style={[styles.menuLabel, { color: theme.ink }]}>{row.label}</Text>
              <Text style={[styles.menuCaption, { color: theme.inkMuted }]}>{row.caption}</Text>
            </View>
            <MaterialIcons name="chevron-right" size={21} color={theme.inkMuted} />
          </Pressable>
        ))}
      </View>
      <View style={styles.footer}>
        <Text style={[styles.footerTitle, { color: theme.ink }]}>Hacksilver Ledger</Text>
        <Text style={[styles.footerText, { color: theme.inkMuted }]}>
          Offline-first personal finance, designed to stay clear.
        </Text>
      </View>
    </Screen>
  );
}

const styles = StyleSheet.create({
  privacy: { flexDirection: 'row', alignItems: 'center', borderRadius: radius.md, padding: spacing.md },
  privacyIcon: {
    width: 38,
    height: 38,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 11,
  },
  copy: { flex: 1 },
  privacyTitle: { fontSize: 14, fontWeight: '800' },
  privacyCaption: { color: '#AEBBB4', fontSize: 11, marginTop: 3 },
  menu: { borderWidth: 1, borderRadius: radius.md, paddingHorizontal: spacing.md, marginTop: spacing.lg },
  menuRow: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingVertical: 14,
    borderBottomWidth: StyleSheet.hairlineWidth,
    borderBottomColor: colors.line,
  },
  menuIcon: {
    width: 38,
    height: 38,
    borderRadius: 12,
    justifyContent: 'center',
    alignItems: 'center',
    marginRight: 11,
  },
  menuLabel: { fontSize: 14, fontWeight: '800' },
  menuCaption: { fontSize: 11, marginTop: 3 },
  footer: { alignItems: 'center', marginTop: spacing.xxl },
  footerTitle: { fontSize: 14, fontWeight: '800' },
  footerText: { fontSize: 11, marginTop: 5 },
});
