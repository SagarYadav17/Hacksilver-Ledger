import PocketBase from 'pocketbase';
import type { SQLiteDatabase } from 'expo-sqlite';
import * as SecureStore from 'expo-secure-store';
import { nowIso } from '@/domain/types';
import type { SyncResult } from '@/domain/types';

const SESSION_KEY = 'hacksilver.pocketbase.session';
const URL_KEY = 'hacksilver.pocketbase.url';
const COLLECTIONS = ['categories', 'accounts', 'loans', 'recurring_transactions', 'transactions'] as const;
const ICON_CODES: Record<string, number> = {
  restaurant: 0xe56c,
  'directions-car': 0xe531,
  'receipt-long': 0xef6e,
  'shopping-bag': 0xf1cc,
  favorite: 0xe87d,
  payments: 0xef63,
  'work-outline': 0xe943,
  'swap-horiz': 0xe8d4,
  category: 0xe574,
};

function quote(value: string): string {
  return `"${value.replaceAll('"', '\\"')}"`;
}

function colorToInt(value: unknown): number {
  const normalized = String(value ?? '#2E6B57').replace('#', '');
  const parsed = Number.parseInt(normalized.length === 6 ? normalized : '2E6B57', 16);
  return Number.isFinite(parsed) ? parsed : 0x2e6b57;
}

function intToColor(value: unknown): string {
  const parsed = Number(value ?? 0x2e6b57);
  return `#${Math.max(0, parsed).toString(16).padStart(6, '0').slice(-6).toUpperCase()}`;
}

function iconNameForCode(value: unknown): string {
  const code = Number(value);
  return Object.entries(ICON_CODES).find(([, iconCode]) => iconCode === code)?.[0] ?? 'category';
}

export class SyncService {
  private client: PocketBase | null = null;

  async restoreSession(): Promise<PocketBase | null> {
    const url = await SecureStore.getItemAsync(URL_KEY);
    const auth = await SecureStore.getItemAsync(SESSION_KEY);
    if (!url || !auth) return null;
    const client = new PocketBase(url);
    try {
      client.authStore.loadFromCookie(auth);
    } catch {
      return null;
    }
    if (!client.authStore.isValid) return null;
    this.client = client;
    return client;
  }

  async configure(url: string): Promise<void> {
    const normalized = url.trim().replace(/\/$/, '');
    if (!normalized) throw new Error('Enter a PocketBase server URL');
    this.client = new PocketBase(normalized);
    await SecureStore.setItemAsync(URL_KEY, normalized);
  }

  get isLoggedIn(): boolean {
    return Boolean(this.client?.authStore.isValid);
  }
  get email(): string | null {
    return (this.client?.authStore.record?.email as string | undefined) ?? null;
  }

  async login(email: string, password: string): Promise<void> {
    if (!this.client) throw new Error('Configure a PocketBase URL first');
    await this.client.collection('users').authWithPassword(email.trim(), password);
    await SecureStore.setItemAsync(SESSION_KEY, this.client.authStore.exportToCookie({ httpOnly: false }));
  }

  async signup(email: string, password: string): Promise<void> {
    if (!this.client) throw new Error('Configure a PocketBase URL first');
    await this.client.collection('users').create({ email: email.trim(), password, passwordConfirm: password });
    await this.login(email, password);
  }

  async logout(): Promise<void> {
    this.client?.authStore.clear();
    await SecureStore.deleteItemAsync(SESSION_KEY);
  }

  async sync(db: SQLiteDatabase): Promise<SyncResult> {
    if (!this.client?.authStore.isValid)
      return { success: false, pushed: 0, pulled: 0, conflicts: 0, error: 'Log in to sync' };
    let pushed = 0;
    let pulled = 0;
    let conflicts = 0;
    try {
      for (const collection of COLLECTIONS) {
        const rows = await this.localRows(db, collection);
        for (const row of rows) {
          pushed += await this.pushOne(collection, row);
        }
      }
      for (const collection of COLLECTIONS) {
        const rows = await this.client.collection(collection).getFullList({ batch: 200, sort: 'updated_at' });
        for (const record of rows) {
          const result = await this.applyRemote(db, collection, record as unknown as Record<string, unknown>);
          pulled += result === 'applied' ? 1 : 0;
          conflicts += result === 'conflict' ? 1 : 0;
        }
      }
      await db.runAsync(
        'UPDATE sync_metadata SET last_sync_at = ?, last_pull_at = ?, last_error = NULL WHERE id = 1',
        nowIso(),
        nowIso(),
      );
      await db.runAsync(
        'INSERT INTO sync_history (id, status, pushed, pulled, conflicts, message, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        `${Date.now()}-sync`,
        'success',
        pushed,
        pulled,
        conflicts,
        null,
        nowIso(),
      );
      return { success: true, pushed, pulled, conflicts };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Sync failed';
      await db.runAsync('UPDATE sync_metadata SET last_error = ? WHERE id = 1', message);
      await db.runAsync(
        'INSERT INTO sync_history (id, status, pushed, pulled, conflicts, message, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        `${Date.now()}-sync`,
        'error',
        pushed,
        pulled,
        conflicts,
        message,
        nowIso(),
      );
      return { success: false, pushed, pulled, conflicts, error: message };
    }
  }

  private async localRows(
    db: SQLiteDatabase,
    collection: (typeof COLLECTIONS)[number],
  ): Promise<Record<string, unknown>[]> {
    const table = collection;
    const rows = await db.getAllAsync<Record<string, unknown>>(`SELECT * FROM ${table} ORDER BY updated_at`);
    return rows;
  }

  private async pushOne(collection: (typeof COLLECTIONS)[number], row: Record<string, unknown>): Promise<number> {
    const pb = this.client!;
    const data = this.toRemote(collection, row);
    const localId = String(row.id);
    const existing = await pb.collection(collection).getList(1, 1, { filter: `local_sync_id = ${quote(localId)}` });
    if (!existing.items.length) {
      await pb.collection(collection).create(data);
      return 1;
    }
    const remote = existing.items[0] as unknown as Record<string, unknown>;
    const localTime = Date.parse(String(row.updated_at));
    const remoteTime = Date.parse(String(remote.updated_at ?? 0));
    if (localTime >= remoteTime) await pb.collection(collection).update(String(remote.id), data);
    return 1;
  }

  private toRemote(collection: string, row: Record<string, unknown>): Record<string, unknown> {
    const base = {
      local_sync_id: row.id,
      user: this.client?.authStore.record?.id,
      updated_at: row.updated_at,
      deleted_at: row.deleted_at ?? null,
    };
    if (collection === 'categories')
      return {
        ...base,
        name: row.name,
        icon_code: ICON_CODES[String(row.icon)] ?? ICON_CODES.category,
        font_family: null,
        font_package: null,
        color_value: colorToInt(row.color),
        type: row.type,
        is_custom: Number(row.is_custom) === 1,
        is_archived: Number(row.is_archived) === 1,
        sort_order: row.sort_order,
      };
    if (collection === 'accounts') return { ...base, name: row.name, type: row.type, balance: row.balance };
    if (collection === 'loans')
      return {
        ...base,
        title: row.title,
        amount: row.amount,
        interest_rate: row.interest_rate,
        tenure_months: row.tenure_months,
        type: row.type,
        start_date: row.start_date,
        emi_amount: row.emi_amount,
        amount_paid: row.amount_paid,
        is_closed: Number(row.is_closed) === 1,
        notes: row.notes ?? null,
      };
    if (collection === 'recurring_transactions')
      return {
        ...base,
        title: row.title,
        amount: row.amount,
        type: row.type,
        frequency: row.frequency,
        start_date: row.start_date,
        next_due_date: row.next_due_date,
        is_active: Number(row.is_active) === 1,
        notes: row.notes ?? null,
        category_sync_id: row.category_id,
        account_sync_id: row.account_id ?? null,
      };
    return {
      ...base,
      title: row.title,
      amount: row.amount,
      date: row.date,
      type: row.type,
      notes: row.notes ?? null,
      original_amount: row.original_amount ?? null,
      original_currency: row.original_currency ?? null,
      category_sync_id: row.category_id,
      account_sync_id: row.account_id ?? null,
      transfer_account_sync_id: row.transfer_account_id ?? null,
      loan_sync_id: row.loan_id ?? null,
      recurring_sync_id: row.recurring_id ?? null,
    };
  }

  private async applyRemote(
    db: SQLiteDatabase,
    collection: string,
    remote: Record<string, unknown>,
  ): Promise<'applied' | 'conflict' | 'skipped'> {
    const id = String(remote.local_sync_id ?? '');
    if (!id) return 'skipped';
    const local = await db.getFirstAsync<Record<string, unknown>>(`SELECT * FROM ${collection} WHERE id = ?`, id);
    if (local && Date.parse(String(local.updated_at)) > Date.parse(String(remote.updated_at ?? 0))) {
      await db.runAsync(
        'INSERT INTO sync_conflicts (id, entity_type, entity_id, local_snapshot, remote_snapshot, winner, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
        `${Date.now()}-${id}`,
        collection,
        id,
        JSON.stringify(local),
        JSON.stringify(remote),
        'local',
        nowIso(),
      );
      return 'conflict';
    }
    const values = this.fromRemote(collection, remote);
    const columns = Object.keys(values);
    const placeholders = columns.map(() => '?').join(', ');
    if (local)
      await db.runAsync(
        `UPDATE ${collection} SET ${columns.map((column) => `${column} = ?`).join(', ')} WHERE id = ?`,
        ...columns.map((column) => values[column] as string | number | null),
        id,
      );
    else
      await db.runAsync(
        `INSERT INTO ${collection} (${columns.join(', ')}) VALUES (${placeholders})`,
        ...columns.map((column) => values[column] as string | number | null),
      );
    return 'applied';
  }

  private fromRemote(collection: string, remote: Record<string, unknown>): Record<string, string | number | null> {
    const base = {
      id: String(remote.local_sync_id),
      updated_at: String(remote.updated_at),
      deleted_at: (remote.deleted_at as string | null) ?? null,
    };
    if (collection === 'categories')
      return {
        ...base,
        name: String(remote.name),
        icon: iconNameForCode(remote.icon_code),
        color: intToColor(remote.color_value),
        type: String(remote.type),
        is_custom: remote.is_custom ? 1 : 0,
        is_archived: remote.is_archived ? 1 : 0,
        sort_order: Number(remote.sort_order ?? 0),
      };
    if (collection === 'accounts')
      return { ...base, name: String(remote.name), type: String(remote.type), balance: Number(remote.balance ?? 0) };
    if (collection === 'loans')
      return {
        ...base,
        title: String(remote.title),
        amount: Number(remote.amount),
        interest_rate: Number(remote.interest_rate ?? 0),
        tenure_months: Number(remote.tenure_months ?? 0),
        type: String(remote.type),
        start_date: String(remote.start_date),
        emi_amount: Number(remote.emi_amount ?? 0),
        amount_paid: Number(remote.amount_paid ?? 0),
        is_closed: remote.is_closed ? 1 : 0,
        notes: (remote.notes as string | null) ?? null,
      };
    if (collection === 'recurring_transactions')
      return {
        ...base,
        title: String(remote.title),
        amount: Number(remote.amount),
        type: String(remote.type),
        category_id: String(remote.category_sync_id),
        account_id: (remote.account_sync_id as string | null) ?? null,
        frequency: String(remote.frequency),
        start_date: String(remote.start_date),
        next_due_date: String(remote.next_due_date),
        is_active: remote.is_active ? 1 : 0,
        notes: (remote.notes as string | null) ?? null,
      };
    return {
      ...base,
      title: String(remote.title),
      amount: Number(remote.amount),
      date: String(remote.date),
      type: String(remote.type),
      category_id: String(remote.category_sync_id),
      account_id: (remote.account_sync_id as string | null) ?? null,
      transfer_account_id: (remote.transfer_account_sync_id as string | null) ?? null,
      notes: (remote.notes as string | null) ?? null,
      original_amount: (remote.original_amount as number | null) ?? null,
      original_currency: (remote.original_currency as string | null) ?? null,
      loan_id: (remote.loan_sync_id as string | null) ?? null,
      recurring_id: (remote.recurring_sync_id as string | null) ?? null,
    };
  }
}

export const syncService = new SyncService();
