import PocketBase, { ClientResponseError } from 'pocketbase';
import type { SQLiteDatabase } from 'expo-sqlite';
import * as SecureStore from 'expo-secure-store';
import { z } from 'zod';
import { newId, nowIso } from '@/domain/types';
import type { SyncResult } from '@/domain/types';

const SESSION_KEY = 'hacksilver.pocketbase.session';
const URL_KEY = 'hacksilver.pocketbase.url';
// Pull order respects local foreign keys.
const COLLECTIONS = ['categories', 'accounts', 'loans', 'recurring_transactions', 'transactions'] as const;
type Collection = (typeof COLLECTIONS)[number];
type Row = Record<string, unknown>;
type SqlValue = string | number | null;
const LOOKUP_CHUNK = 50;
const LOCAL_HOSTS = new Set(['localhost', '127.0.0.1', '10.0.2.2', '[::1]']);
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

// PocketBase returns "" for empty text fields; store those as NULL locally.
const optText = z
  .string()
  .nullish()
  .transform((value) => value || null);
const text = z.string().min(1);
const isoDate = z.string().refine((value) => !Number.isNaN(Date.parse(value)), 'Invalid date');
const num = z.number().finite();
const bool = z.boolean().nullish().transform(Boolean);
const categoryType = z.enum(['income', 'expense', 'transfer']);
const entryType = z.enum(['income', 'expense', 'transfer', 'adjustment']);
const baseSchema = z.object({ local_sync_id: text, updated_at: isoDate, deleted_at: optText });

const REMOTE_SCHEMAS = {
  categories: baseSchema.extend({
    name: text,
    icon_code: num.nullish(),
    color_value: num.nullish(),
    type: categoryType,
    is_custom: bool,
    is_archived: bool,
    sort_order: num.nullish(),
  }),
  accounts: baseSchema.extend({
    name: text,
    type: z.enum(['cash', 'bank', 'credit_card', 'other']),
    balance: num.nullish(),
  }),
  loans: baseSchema.extend({
    title: text,
    amount: num,
    interest_rate: num.nullish(),
    tenure_months: num.nullish(),
    type: z.enum(['given', 'taken']),
    start_date: text,
    emi_amount: num.nullish(),
    amount_paid: num.nullish(),
    is_closed: bool,
    notes: optText,
  }),
  recurring_transactions: baseSchema.extend({
    title: text,
    amount: num,
    type: entryType,
    frequency: z.enum(['daily', 'monthly', 'quarterly', 'yearly']),
    start_date: text,
    next_due_date: text,
    is_active: bool,
    notes: optText,
    category_sync_id: text,
    account_sync_id: optText,
  }),
  transactions: baseSchema.extend({
    title: text,
    amount: num,
    date: text,
    type: entryType,
    notes: optText,
    original_amount: num.nullish(),
    original_currency: optText,
    category_sync_id: text,
    account_sync_id: optText,
    transfer_account_sync_id: optText,
    loan_sync_id: optText,
    recurring_sync_id: optText,
  }),
} satisfies Record<Collection, z.ZodType>;

/**
 * Normalizes a server URL. Requires https:// except for local development hosts
 * (localhost, 127.0.0.1, ::1, 10.0.2.2 Android emulator, *.localhost).
 */
export function validateServerUrl(input: string): string {
  const trimmed = input.trim();
  if (!trimmed) throw new Error('Enter a PocketBase server URL');
  let parsed: URL;
  try {
    parsed = new URL(trimmed);
  } catch {
    throw new Error('Enter a valid URL, for example https://pb.example.com');
  }
  const host = parsed.hostname.toLowerCase();
  const isLocal = LOCAL_HOSTS.has(host) || host === '::1' || host.endsWith('.localhost');
  if (parsed.protocol === 'http:' && !isLocal)
    throw new Error('Use https:// for remote servers (http:// is only allowed for localhost)');
  if (parsed.protocol !== 'https:' && parsed.protocol !== 'http:')
    throw new Error('Server URL must start with https://');
  if (parsed.username || parsed.password) throw new Error('Do not put credentials in the server URL');
  if (parsed.search || parsed.hash) throw new Error('Server URL must not contain a query or fragment');
  return `${parsed.origin}${parsed.pathname}`.replace(/\/+$/, '');
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

/** Legacy/invalid values (e.g. an old plain timestamp) reset to a full, idempotent pull. */
function parsePullCursors(value: string | null): Partial<Record<Collection, string>> {
  if (!value) return {};
  try {
    const parsed: unknown = JSON.parse(value);
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) return {};
    return Object.fromEntries(
      Object.entries(parsed).filter(
        ([key, cursor]) => (COLLECTIONS as readonly string[]).includes(key) && typeof cursor === 'string',
      ),
    );
  } catch {
    return {};
  }
}

function isAuthError(error: unknown): boolean {
  return error instanceof ClientResponseError && [401, 403, 404].includes(error.status);
}

export class SyncService {
  private client: PocketBase | null = null;
  private inFlight: Promise<SyncResult> | null = null;

  constructor(private readonly createClient: (url: string) => PocketBase = (url) => new PocketBase(url)) {}

  async restoreSession(): Promise<PocketBase | null> {
    const url = await SecureStore.getItemAsync(URL_KEY);
    const auth = await SecureStore.getItemAsync(SESSION_KEY);
    if (!url || !auth) return null;
    let client: PocketBase;
    try {
      client = this.createClient(validateServerUrl(url));
      client.authStore.loadFromCookie(auth);
    } catch {
      return null;
    }
    if (!client.authStore.isValid) {
      await SecureStore.deleteItemAsync(SESSION_KEY);
      return null;
    }
    try {
      await client.collection('users').authRefresh();
      await SecureStore.setItemAsync(SESSION_KEY, client.authStore.exportToCookie({ httpOnly: false }));
    } catch (error) {
      // Offline or server hiccup: keep the still-valid token. Rejected token: sign out.
      if (isAuthError(error) || !client.authStore.isValid) {
        client.authStore.clear();
        await SecureStore.deleteItemAsync(SESSION_KEY);
        return null;
      }
    }
    this.client = client;
    return client;
  }

  async configure(url: string): Promise<void> {
    const normalized = validateServerUrl(url);
    this.client = this.createClient(normalized);
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

  /** Concurrent callers share one in-flight run. */
  sync(db: SQLiteDatabase): Promise<SyncResult> {
    this.inFlight ??= this.runSync(db).finally(() => {
      this.inFlight = null;
    });
    return this.inFlight;
  }

  private async runSync(db: SQLiteDatabase): Promise<SyncResult> {
    const pb = this.client;
    if (!pb?.authStore.isValid) return { success: false, pushed: 0, pulled: 0, conflicts: 0, error: 'Log in to sync' };
    const startedAt = nowIso();
    const meta = await db.getFirstAsync<{ last_sync_at: string | null; last_pull_at: string | null }>(
      'SELECT last_sync_at, last_pull_at FROM sync_metadata WHERE id = 1',
    );
    let pushed = 0;
    let pulled = 0;
    let conflicts = 0;
    let failed = 0;
    try {
      for (const collection of COLLECTIONS)
        pushed += await this.pushChanged(db, collection, meta?.last_sync_at ?? null);
      // Pull cursor: per-collection max server-set `updated` (JSON map in last_pull_at).
      // Collections are fetched one after another, so a single shared cursor could skip records.
      const cursors = parsePullCursors(meta?.last_pull_at ?? null);
      for (const collection of COLLECTIONS) {
        const since = cursors[collection];
        // `>=` so records sharing the boundary timestamp are not skipped; re-pulls are idempotent.
        const records = await pb.collection(collection).getFullList({
          batch: 200,
          sort: 'updated',
          ...(since ? { filter: pb.filter('updated >= {:since}', { since }) } : {}),
        });
        let collectionFailed = 0;
        let maxUpdated = since;
        for (const record of records) {
          const result = await this.applyRemote(db, collection, record as unknown as Row);
          if (result === 'applied') pulled += 1;
          else if (result === 'conflict') conflicts += 1;
          else if (result === 'failed') collectionFailed += 1;
          const updated = typeof record.updated === 'string' ? record.updated : '';
          if (updated && (!maxUpdated || updated > maxUpdated)) maxUpdated = updated;
        }
        failed += collectionFailed;
        // Keep the cursor when records failed so they are retried next time.
        if (!collectionFailed && maxUpdated) cursors[collection] = maxUpdated;
      }
      // Push cursor uses the start time so local edits made during this run are pushed next time.
      await db.runAsync(
        'UPDATE sync_metadata SET last_sync_at = ?, last_pull_at = ?, last_error = NULL WHERE id = 1',
        startedAt,
        JSON.stringify(cursors),
      );
      const message = failed ? `${failed} remote record${failed === 1 ? '' : 's'} failed to apply` : null;
      await this.recordHistory(db, failed ? 'partial' : 'success', pushed, pulled, conflicts, message);
      return { success: true, pushed, pulled, conflicts, ...(message ? { error: message } : {}) };
    } catch (error) {
      const message = error instanceof Error ? error.message : 'Sync failed';
      await db.runAsync('UPDATE sync_metadata SET last_error = ? WHERE id = 1', message);
      await this.recordHistory(db, 'error', pushed, pulled, conflicts, message);
      return { success: false, pushed, pulled, conflicts, error: message };
    }
  }

  private async recordHistory(
    db: SQLiteDatabase,
    status: string,
    pushed: number,
    pulled: number,
    conflicts: number,
    message: string | null,
  ): Promise<void> {
    await db.runAsync(
      'INSERT INTO sync_history (id, status, pushed, pulled, conflicts, message, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      newId(),
      status,
      pushed,
      pulled,
      conflicts,
      message,
      nowIso(),
    );
  }

  private async pushChanged(db: SQLiteDatabase, collection: Collection, since: string | null): Promise<number> {
    const pb = this.client!;
    const rows = since
      ? await db.getAllAsync<Row>(`SELECT * FROM ${collection} WHERE updated_at > ? ORDER BY updated_at`, since)
      : await db.getAllAsync<Row>(`SELECT * FROM ${collection} ORDER BY updated_at`);
    let pushed = 0;
    for (let start = 0; start < rows.length; start += LOOKUP_CHUNK) {
      const chunk = rows.slice(start, start + LOOKUP_CHUNK);
      const params = Object.fromEntries(chunk.map((row, index) => [`id${index}`, String(row.id)]));
      const filter = pb.filter(chunk.map((_, index) => `local_sync_id = {:id${index}}`).join(' || '), params);
      const existing = await pb.collection(collection).getFullList({ batch: 200, filter });
      const remoteById = new Map(existing.map((record) => [String(record.local_sync_id), record as unknown as Row]));
      for (const row of chunk) {
        const data = this.toRemote(collection, row);
        const remote = remoteById.get(String(row.id));
        if (!remote) await pb.collection(collection).create(data);
        else if (Date.parse(String(row.updated_at)) >= Date.parse(String(remote.updated_at ?? 0)))
          await pb.collection(collection).update(String(remote.id), data);
        else continue;
        pushed += 1;
      }
    }
    return pushed;
  }

  private toRemote(collection: Collection, row: Row): Row {
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

  /** Applies one remote record; never throws so one bad record cannot abort the sync. */
  private async applyRemote(
    db: SQLiteDatabase,
    collection: Collection,
    remote: Row,
  ): Promise<'applied' | 'conflict' | 'skipped' | 'failed'> {
    const parsed = REMOTE_SCHEMAS[collection].safeParse(remote);
    if (!parsed.success) return 'failed';
    try {
      const values = this.fromRemote(collection, parsed.data);
      const id = String(values.id);
      const local = await db.getFirstAsync<Row>(`SELECT * FROM ${collection} WHERE id = ?`, id);
      if (local) {
        const localTime = Date.parse(String(local.updated_at));
        const remoteTime = Date.parse(String(values.updated_at));
        if (localTime === remoteTime) return 'skipped';
        if (localTime > remoteTime) {
          await db.runAsync(
            'INSERT INTO sync_conflicts (id, entity_type, entity_id, local_snapshot, remote_snapshot, winner, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
            newId(),
            collection,
            id,
            JSON.stringify(local),
            JSON.stringify(remote),
            'local',
            nowIso(),
          );
          return 'conflict';
        }
      }
      const columns = Object.keys(values);
      const args = columns.map((column) => values[column]);
      if (local)
        await db.runAsync(
          `UPDATE ${collection} SET ${columns.map((column) => `${column} = ?`).join(', ')} WHERE id = ?`,
          ...args,
          id,
        );
      else
        await db.runAsync(
          `INSERT INTO ${collection} (${columns.join(', ')}) VALUES (${columns.map(() => '?').join(', ')})`,
          ...args,
        );
      return 'applied';
    } catch {
      return 'failed';
    }
  }

  private fromRemote(
    collection: Collection,
    data: z.infer<(typeof REMOTE_SCHEMAS)[Collection]>,
  ): Record<string, SqlValue> {
    const base = { id: data.local_sync_id, updated_at: data.updated_at, deleted_at: data.deleted_at };
    if (collection === 'categories') {
      const remote = data as z.infer<typeof REMOTE_SCHEMAS.categories>;
      return {
        ...base,
        name: remote.name,
        icon: iconNameForCode(remote.icon_code),
        color: intToColor(remote.color_value),
        type: remote.type,
        is_custom: remote.is_custom ? 1 : 0,
        is_archived: remote.is_archived ? 1 : 0,
        sort_order: remote.sort_order ?? 0,
      };
    }
    if (collection === 'accounts') {
      const remote = data as z.infer<typeof REMOTE_SCHEMAS.accounts>;
      return { ...base, name: remote.name, type: remote.type, balance: remote.balance ?? 0 };
    }
    if (collection === 'loans') {
      const remote = data as z.infer<typeof REMOTE_SCHEMAS.loans>;
      return {
        ...base,
        title: remote.title,
        amount: remote.amount,
        interest_rate: remote.interest_rate ?? 0,
        tenure_months: remote.tenure_months ?? 0,
        type: remote.type,
        start_date: remote.start_date,
        emi_amount: remote.emi_amount ?? 0,
        amount_paid: remote.amount_paid ?? 0,
        is_closed: remote.is_closed ? 1 : 0,
        notes: remote.notes,
      };
    }
    if (collection === 'recurring_transactions') {
      const remote = data as z.infer<typeof REMOTE_SCHEMAS.recurring_transactions>;
      return {
        ...base,
        title: remote.title,
        amount: remote.amount,
        type: remote.type,
        category_id: remote.category_sync_id,
        account_id: remote.account_sync_id,
        frequency: remote.frequency,
        start_date: remote.start_date,
        next_due_date: remote.next_due_date,
        is_active: remote.is_active ? 1 : 0,
        notes: remote.notes,
      };
    }
    const remote = data as z.infer<typeof REMOTE_SCHEMAS.transactions>;
    return {
      ...base,
      title: remote.title,
      amount: remote.amount,
      date: remote.date,
      type: remote.type,
      category_id: remote.category_sync_id,
      account_id: remote.account_sync_id,
      transfer_account_id: remote.transfer_account_sync_id,
      notes: remote.notes,
      // PocketBase stores an empty number as 0; only keep it alongside a currency.
      original_amount: remote.original_currency ? (remote.original_amount ?? null) : null,
      original_currency: remote.original_currency,
      loan_id: remote.loan_sync_id,
      recurring_id: remote.recurring_sync_id,
    };
  }
}

export const syncService = new SyncService();
