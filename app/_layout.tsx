import { Stack } from 'expo-router';
import { useEffect } from 'react';
import { StatusBar } from 'expo-status-bar';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SQLiteProvider } from 'expo-sqlite';
import { initializeDatabase } from '@/data/schema';
import { useAppTheme } from '@/lib/theme';
import { useAppStore } from '@/store/app-store';
import { registerBackgroundSync } from '@/data/background';
import { useSQLiteContext } from 'expo-sqlite';
import * as Network from 'expo-network';
import { syncService } from '@/data/sync';
import { AppLockGate } from '@/components/security';

const queryClient = new QueryClient({
  defaultOptions: { queries: { staleTime: 15_000, retry: 1 } },
});

export default function RootLayout() {
  const { dark } = useAppTheme();
  return (
    <QueryClientProvider client={queryClient}>
      <SQLiteProvider databaseName="hacksilver_ledger.db" onInit={initializeDatabase} useSuspense>
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
    return () => subscription.remove();
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
