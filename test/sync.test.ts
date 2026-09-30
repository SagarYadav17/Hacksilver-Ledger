import { beforeEach, describe, expect, test } from 'bun:test';
import { ClientResponseError } from 'pocketbase';
import type PocketBase from 'pocketbase';
import * as SecureStore from 'expo-secure-store';
import type { SQLiteDatabase } from 'expo-sqlite';
import { initializeDatabase } from '@/data/schema';
import { SyncService, validateServerUrl } from '@/data/sync';
import { MemoryDatabase } from './memory-db';
import { resetSecureStore } from './setup';

type Rec = Record<string, unknown>;

/** Minimal in-memory PocketBase stand-in. `filter()` encodes raw+params as JSON so queries can be evaluated. */
class FakePocketBase {
  store: Record<string, Rec[]> = {};
  filterCalls: Array<{ raw: string; params: Record<string, unknown> }> = [];
  listCalls = 0;
  creates = 0;
  updates = 0;
  authStore = {
    isValid: true,
    record: { id: 'user1', email: 'a@example.com' },
    clear: () => {
      this.authStore.isValid = false;
    },
    loadFromCookie: () => {},
    exportToCookie: () => 'cookie',
  };

  filter(raw: string, params: Record<string, unknown>): string {
    this.filterCalls.push({ raw, params });
    return JSON.stringify({ raw, params });
  }

  refreshError: unknown = null;
  private clock = 0;

  /** Server-set autodate in PocketBase's `YYYY-MM-DD HH:MM:SS.sssZ` format, strictly increasing. */
  tick(): string {
    this.clock += 1;
    return new Date(Date.UTC(2026, 0, 1) + this.clock * 1000).toISOString().replace('T', ' ');
  }

  collection(name: string) {
    const refresh = this.refreshError;
    const rows = (this.store[name] ??= []);
    return {
      authRefresh: async () => {
        if (refresh) throw refresh;
      },
      getFullList: async (options: { filter?: string } = {}) => {
        this.listCalls += 1;
        await Bun.sleep(1);
        const sorted = rows.toSorted((a, b) => String(a.updated).localeCompare(String(b.updated)));
        if (!options.filter) return sorted;
        const { raw, params } = JSON.parse(options.filter) as { raw: string; params: Record<string, string> };
        if (raw.includes('local_sync_id')) {
          const ids = new Set(Object.values(params));
          return sorted.filter((row) => ids.has(String(row.local_sync_id)));
        }
        expect(raw).toBe('updated >= {:since}');
        return sorted.filter((row) => String(row.updated) >= params.since);
      },
      create: async (data: Rec) => {
        this.creates += 1;
        rows.push({ ...data, id: `r${rows.length}`, updated: this.tick() });
      },
      update: async (id: string, data: Rec) => {
        this.updates += 1;
        const index = rows.findIndex((row) => row.id === id);
        rows[index] = { ...data, id, updated: this.tick() };
      },
    };
  }
}

async function setup() {
  const memory = new MemoryDatabase();
  const db = memory as unknown as SQLiteDatabase;
  await initializeDatabase(db);
  const fake = new FakePocketBase();
  const service = new SyncService(() => fake as unknown as PocketBase);
  await service.configure('https://pb.example.com');
  return { db, fake, service };
}

beforeEach(() => resetSecureStore());

describe('validateServerUrl', () => {
  test('accepts https and strips trailing slash', () => {
    expect(validateServerUrl(' https://pb.example.com/ ')).toBe('https://pb.example.com');
    expect(validateServerUrl('https://example.com/pb/')).toBe('https://example.com/pb');
  });
  test('allows http only for local hosts', () => {
    for (const url of [
      'http://localhost:8090',
      'http://127.0.0.1:8090',
      'http://10.0.2.2:8090',
      'http://pb.localhost',
      'http://[::1]:8090',
    ])
      expect(() => validateServerUrl(url)).not.toThrow();
    expect(() => validateServerUrl('http://pb.example.com')).toThrow(/https/);
    expect(() => validateServerUrl('http://192.168.1.5:8090')).toThrow(/https/);
    expect(() => validateServerUrl('http://localhost.evil.com')).toThrow(/https/);
  });
  test('rejects junk', () => {
    expect(() => validateServerUrl('')).toThrow();
    expect(() => validateServerUrl('pb.example.com')).toThrow();
    expect(() => validateServerUrl('ftp://pb.example.com')).toThrow();
    expect(() => validateServerUrl('https://user:pw@pb.example.com')).toThrow();
  });
});

describe('SyncService.sync', () => {
  test('concurrent calls share one run', async () => {
    const { db, fake, service } = await setup();
    const [a, b] = await Promise.all([service.sync(db), service.sync(db)]);
    expect(a).toBe(b);
    expect(a.success).toBe(true);
    expect(fake.creates).toBe(8);
    const history = await db.getAllAsync<{ id: string }>('SELECT id FROM sync_history');
    expect(history).toHaveLength(1);
    expect(history[0].id).toMatch(/^[0-9a-f-]{36}$/);
  });

  test('lookups and pulls go through pb.filter params', async () => {
    const { db, fake, service } = await setup();
    await service.sync(db);
    const lookup = fake.filterCalls.find((call) => call.raw.includes('local_sync_id'))!;
    expect(lookup.raw).toContain('local_sync_id = {:id0}');
    expect(Object.values(lookup.params).every((value) => typeof value === 'string')).toBe(true);
    await service.sync(db);
    expect(fake.filterCalls.some((call) => call.raw === 'updated >= {:since}')).toBe(true);
  });

  test('pushes only rows changed since last sync', async () => {
    const { db, fake, service } = await setup();
    await service.sync(db);
    expect(fake.creates).toBe(8);
    const noop = await service.sync(db);
    expect(noop.pushed).toBe(0);
    expect(noop.pulled).toBe(0);

    await Bun.sleep(2);
    const later = new Date(Date.now() + 1000).toISOString();
    const row = await db.getFirstAsync<{ id: string }>('SELECT id FROM categories LIMIT 1');
    await db.runAsync("UPDATE categories SET name = 'Renamed', updated_at = ? WHERE id = ?", later, row!.id);
    const result = await service.sync(db);
    expect(result.pushed).toBe(1);
    expect(fake.updates).toBe(1);
    expect(fake.store.categories.find((record) => record.local_sync_id === row!.id)?.name).toBe('Renamed');
  });

  test('pull cursor uses server `updated`, so late-pushed old edits still arrive', async () => {
    const { db, fake, service } = await setup();
    await service.sync(db);
    // Another device edited offline long ago and only now pushes: old updated_at, new server `updated`.
    fake.store.accounts.push({
      id: 'late',
      updated: fake.tick(),
      local_sync_id: 'acc-late',
      updated_at: '2020-01-01T00:00:00.000Z',
      deleted_at: '',
      name: 'Offline edit',
      type: 'cash',
      balance: 0,
    });
    const result = await service.sync(db);
    expect(result.pulled).toBe(1);
    expect(await db.getFirstAsync<{ name: string }>("SELECT name FROM accounts WHERE id = 'acc-late'")).toEqual({
      name: 'Offline edit',
    });
    // Boundary record is re-fetched by `>=` but skipped as unchanged.
    expect((await service.sync(db)).pulled).toBe(0);
  });

  test('legacy plain-timestamp cursor falls back to a full pull', async () => {
    const { db, service } = await setup();
    await service.sync(db);
    await db.runAsync("UPDATE sync_metadata SET last_pull_at = '2026-01-01T00:00:00.000Z' WHERE id = 1");
    const result = await service.sync(db);
    expect(result.success).toBe(true);
    expect(result.pulled).toBe(0);
  });

  test('invalid or failing remote records are skipped, not fatal', async () => {
    const { db, fake, service } = await setup();
    const now = new Date().toISOString();
    fake.store.accounts = [
      {
        id: 'a1',
        updated: fake.tick(),
        local_sync_id: 'acc-good',
        updated_at: now,
        deleted_at: '',
        name: 'Wallet',
        type: 'cash',
        balance: 5,
      },
      {
        id: 'a2',
        updated: fake.tick(),
        local_sync_id: 'acc-bad',
        updated_at: 'not-a-date',
        name: 'Broken',
        type: 'cash',
      },
    ];
    fake.store.transactions = [
      {
        id: 't1',
        updated: fake.tick(),
        local_sync_id: 'tx-orphan',
        updated_at: now,
        title: 'Orphan',
        amount: 1,
        date: now,
        type: 'expense',
        category_sync_id: 'missing-category',
      },
    ];
    const result = await service.sync(db);
    expect(result.success).toBe(true);
    expect(result.error).toBe('2 remote records failed to apply');
    const account = await db.getFirstAsync<{ deleted_at: string | null }>(
      "SELECT deleted_at FROM accounts WHERE id = 'acc-good'",
    );
    expect(account).toEqual({ deleted_at: null });
    const meta = await db.getFirstAsync<{ last_pull_at: string | null }>(
      'SELECT last_pull_at FROM sync_metadata WHERE id = 1',
    );
    const cursors = JSON.parse(meta!.last_pull_at!) as Record<string, string>;
    expect(cursors.accounts).toBeUndefined();
    expect(cursors.transactions).toBeUndefined();
    expect(cursors.categories).toMatch(/^2026-01-01 /);
    const history = await db.getFirstAsync<{ status: string }>('SELECT status FROM sync_history');
    expect(history?.status).toBe('partial');
  });

  test('requires login', async () => {
    const { db, fake, service } = await setup();
    fake.authStore.isValid = false;
    expect((await service.sync(db)).success).toBe(false);
  });
});

describe('SyncService.restoreSession', () => {
  async function restoreWith(error: unknown) {
    const fake = new FakePocketBase();
    fake.refreshError = error;
    await SecureStore.setItemAsync('hacksilver.pocketbase.url', 'https://pb.example.com');
    await SecureStore.setItemAsync('hacksilver.pocketbase.session', 'old');
    const service = new SyncService(() => fake as unknown as PocketBase);
    return {
      client: await service.restoreSession(),
      session: await SecureStore.getItemAsync('hacksilver.pocketbase.session'),
    };
  }

  test('refreshes and persists the token', async () => {
    const { client, session } = await restoreWith(null);
    expect(client).not.toBeNull();
    expect(session).toBe('cookie');
  });
  test('clears session when the server rejects the token', async () => {
    const { client, session } = await restoreWith(new ClientResponseError({ status: 401 }));
    expect(client).toBeNull();
    expect(session).toBeNull();
  });
  test('keeps a valid session when offline', async () => {
    const { client, session } = await restoreWith(new ClientResponseError({ status: 0, isAbort: false }));
    expect(client).not.toBeNull();
    expect(session).toBe('old');
  });
  test('rejects a stored insecure URL', async () => {
    await SecureStore.setItemAsync('hacksilver.pocketbase.url', 'http://pb.example.com');
    await SecureStore.setItemAsync('hacksilver.pocketbase.session', 'old');
    expect(await new SyncService(() => new FakePocketBase() as unknown as PocketBase).restoreSession()).toBeNull();
  });
});
