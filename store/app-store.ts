import { create } from 'zustand';
import * as SecureStore from 'expo-secure-store';
import type { SyncState } from '@/domain/types';

interface AppState {
  currency: string;
  hideBalances: boolean;
  syncState: SyncState;
  lastSyncAt: string | null;
  setCurrency: (currency: string) => void;
  setHideBalances: (hide: boolean) => void;
  setSyncState: (state: SyncState, lastSyncAt?: string | null) => void;
  hydrate: () => Promise<void>;
}

export const useAppStore = create<AppState>((set) => ({
  currency: 'INR',
  hideBalances: false,
  syncState: 'idle',
  lastSyncAt: null,
  setCurrency: (currency) => {
    set({ currency });
    void SecureStore.setItemAsync('hacksilver.currency', currency);
  },
  setHideBalances: (hideBalances) => {
    set({ hideBalances });
    void SecureStore.setItemAsync('hacksilver.hide-balances', String(hideBalances));
  },
  setSyncState: (syncState, lastSyncAt) => set({ syncState, ...(lastSyncAt === undefined ? {} : { lastSyncAt }) }),
  hydrate: async () => {
    const [currency, hideBalances] = await Promise.all([
      SecureStore.getItemAsync('hacksilver.currency'),
      SecureStore.getItemAsync('hacksilver.hide-balances'),
    ]);
    set({ currency: currency ?? 'INR', hideBalances: hideBalances === 'true' });
  },
}));
