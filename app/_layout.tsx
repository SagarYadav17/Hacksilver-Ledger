import { Stack } from 'expo-router';
import { useCallback, useEffect, useState } from 'react';
import { ActivityIndicator, AppState, Pressable, StyleSheet, Text, View } from 'react-native';
import { StatusBar } from 'expo-status-bar';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SQLiteProvider, type SQLiteDatabase } from 'expo-sqlite';
import { initializeDatabase } from '@/data/schema';
import { applyKey, DB_NAME, prepareDatabase } from '@/data/database';
import { LedgerRepository } from '@/data/repository';
import { purgeExportedFiles } from '@/data/backup';
import { radius, spacing, useAppTheme } from '@/lib/theme';
import { useAppStore } from '@/store/app-store';
import { registerBackgroundSync } from '@/data/background';
import { useSQLiteContext } from 'expo-sqlite';
import * as Network from 'expo-network';
import { syncService } from '@/data/sync';
import { AppLockGate } from '@/components/security';

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 15_000, retry: 1 } },
});

const initLedger = async (db: SQLiteDatabase) => {
  await applyKey(db);
  await initializeDatabase(db);
};

export default function RootLayout() {
  const { dark, colors: theme } = useAppTheme();
  const [status, setStatus] = useState<'loading' | 'ready' | Error>('loading');
  const prepare = useCallback(() => {
    setStatus('loading');
    prepareDatabase().then(
      () => setStatus('ready'),
      (error) => setStatus(error instanceof Error ? error : new Error(String(error))),
    );
  }, []);
  useEffect(prepare, [prepare]);
  useEffect(() => {
    void purgeExportedFiles();
  }, []);
  if (status !== 'ready')
    return (
      <View style={[styles.center, { backgroundColor: theme.canvas }]}>
        <StatusBar style={dark ? 'light' : 'dark'} />
        {status === 'loading' ? (
          <ActivityIndicator color={theme.primary} />
        ) : (
          <>
            <Text style={[styles.title, { color: theme.ink }]}>Could not open your ledger</Text>
            <Text style={[styles.text, { color: theme.inkMuted }]}>{status.message}</Text>
            <Pressable onPress={prepare} style={[styles.retry, { backgroundColor: theme.primary }]}>
              <Text style={styles.retryText}>Try again</Text>
            </Pressable>
          </>
        )}
      </View>
    );
  return (
    <QueryClientProvider client={queryClient}>
      <SQLiteProvider databaseName={DB_NAME} onInit={initLedger} useSuspense>
        <AppRuntime dark={dark} />
      </SQLiteProvider>
    </QueryClientProvider>
  );
}

function AppRuntime({ dark }: { dark: boolean }) {
  const hydrate = useAppStore((state) => state.hydrate);
  const db = useSQLiteContext();
  useEffect(() => {
    void hydrate();
    void registerBackgroundSync();
    void syncService.restoreSession();
    const subscription = Network.addNetworkStateListener((state) => {
      if (state.isConnected && syncService.isLoggedIn) void syncService.sync(db);
    });
    const postDue = async () => {
      try {
        if ((await new LedgerRepository(db).postDueRecurring()) > 0)
          await Promise.all(
            ['dashboard', 'accounts', 'transactions', 'recurring'].map((queryKey) =>
              queryClient.invalidateQueries({ queryKey: [queryKey] }),
            ),
          );
      } catch {
        // Recurring posting retries on the next foreground.
      }
    };
    void postDue();
    const appState = AppState.addEventListener('change', (state) => {
      if (state === 'active') void postDue();
    });
    return () => {
      subscription.remove();
      appState.remove();
    };
  }, [db, hydrate]);
  return (
    <>
      <StatusBar style={dark ? 'light' : 'dark'} />
      <AppLockGate>
        <Stack screenOptions={{ headerShown: false, animation: 'fade_from_bottom', animationDuration: 280 }}>
          <Stack.Screen name="(tabs)" />
          <Stack.Screen name="transaction/new" options={{ presentation: 'modal', animation: 'slide_from_bottom' }} />
          <Stack.Screen name="account/new" options={{ presentation: 'modal', animation: 'slide_from_bottom' }} />
          <Stack.Screen name="account/[id]" />
          <Stack.Screen name="loan/new" options={{ presentation: 'modal', animation: 'slide_from_bottom' }} />
          <Stack.Screen name="analytics" />
          <Stack.Screen name="categories" />
          <Stack.Screen name="recurring" />
          <Stack.Screen name="recurring/new" options={{ presentation: 'modal', animation: 'slide_from_bottom' }} />
          <Stack.Screen name="sync-backup" />
          <Stack.Screen name="settings" />
        </Stack>
      </AppLockGate>
    </>
  );
}

const styles = StyleSheet.create({
  center: { flex: 1, justifyContent: 'center', alignItems: 'center', padding: spacing.xl },
  title: { fontSize: 18, fontWeight: '800', textAlign: 'center' },
  text: { fontSize: 12, lineHeight: 18, marginTop: spacing.xs, textAlign: 'center' },
  retry: { borderRadius: radius.pill, paddingHorizontal: 18, paddingVertical: 11, marginTop: spacing.lg },
  retryText: { color: '#fff', fontSize: 12, fontWeight: '800' },
});
