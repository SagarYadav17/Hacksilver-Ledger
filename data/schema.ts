import type { SQLiteDatabase } from 'expo-sqlite';
import { newId, nowIso } from '@/domain/types';

const DEFAULT_CATEGORIES = [
  ['Food & dining', 'restaurant', '#F47C6A', 'expense'],
  ['Transport', 'directions-car', '#6B8AFD', 'expense'],
  ['Bills & utilities', 'receipt-long', '#A881F2', 'expense'],
  ['Shopping', 'shopping-bag', '#E69A50', 'expense'],
  ['Health', 'favorite', '#E67C9A', 'expense'],
  ['Salary', 'payments', '#3EAD8C', 'income'],
  ['Freelance', 'work-outline', '#67B6A0', 'income'],
  ['Transfer', 'swap-horiz', '#87909C', 'transfer'],
] as const;

export async function initializeDatabase(db: SQLiteDatabase): Promise<void> {
  await db.execAsync(`
    PRAGMA journal_mode = WAL;
    PRAGMA foreign_keys = ON;

    CREATE TABLE IF NOT EXISTS categories (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      icon TEXT NOT NULL,
      color TEXT NOT NULL,
      type TEXT NOT NULL,
      is_custom INTEGER NOT NULL DEFAULT 1,
      is_archived INTEGER NOT NULL DEFAULT 0,
      sort_order INTEGER NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS accounts (
      id TEXT PRIMARY KEY NOT NULL,
      name TEXT NOT NULL,
      type TEXT NOT NULL,
      balance REAL NOT NULL DEFAULT 0,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS loans (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      interest_rate REAL NOT NULL DEFAULT 0,
      tenure_months INTEGER NOT NULL,
      type TEXT NOT NULL,
      start_date TEXT NOT NULL,
      emi_amount REAL NOT NULL,
      amount_paid REAL NOT NULL DEFAULT 0,
      is_closed INTEGER NOT NULL DEFAULT 0,
      notes TEXT,
      updated_at TEXT NOT NULL,
      deleted_at TEXT
    );

    CREATE TABLE IF NOT EXISTS recurring_transactions (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      type TEXT NOT NULL,
      category_id TEXT NOT NULL,
      account_id TEXT,
      frequency TEXT NOT NULL,
      start_date TEXT NOT NULL,
      next_due_date TEXT NOT NULL,
      is_active INTEGER NOT NULL DEFAULT 1,
      notes TEXT,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY(category_id) REFERENCES categories(id),
      FOREIGN KEY(account_id) REFERENCES accounts(id)
    );

    CREATE TABLE IF NOT EXISTS transactions (
      id TEXT PRIMARY KEY NOT NULL,
      title TEXT NOT NULL,
      amount REAL NOT NULL,
      date TEXT NOT NULL,
      type TEXT NOT NULL,
      category_id TEXT NOT NULL,
      account_id TEXT,
      transfer_account_id TEXT,
      notes TEXT,
      original_amount REAL,
      original_currency TEXT,
      loan_id TEXT,
      recurring_id TEXT,
      updated_at TEXT NOT NULL,
      deleted_at TEXT,
      FOREIGN KEY(category_id) REFERENCES categories(id),
      FOREIGN KEY(account_id) REFERENCES accounts(id),
      FOREIGN KEY(transfer_account_id) REFERENCES accounts(id),
      FOREIGN KEY(loan_id) REFERENCES loans(id),
      FOREIGN KEY(recurring_id) REFERENCES recurring_transactions(id)
    );

    CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(date DESC);
    CREATE INDEX IF NOT EXISTS idx_transactions_sync ON transactions(updated_at, deleted_at);

    CREATE TABLE IF NOT EXISTS sync_metadata (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      pocketbase_url TEXT,
      last_sync_at TEXT,
      last_pull_at TEXT,
      last_error TEXT,
      pending_count INTEGER NOT NULL DEFAULT 0
    );

    CREATE TABLE IF NOT EXISTS sync_history (
      id TEXT PRIMARY KEY NOT NULL,
      status TEXT NOT NULL,
      pushed INTEGER NOT NULL DEFAULT 0,
      pulled INTEGER NOT NULL DEFAULT 0,
      conflicts INTEGER NOT NULL DEFAULT 0,
      message TEXT,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS sync_conflicts (
      id TEXT PRIMARY KEY NOT NULL,
      entity_type TEXT NOT NULL,
      entity_id TEXT NOT NULL,
      local_snapshot TEXT NOT NULL,
      remote_snapshot TEXT NOT NULL,
      winner TEXT NOT NULL,
      created_at TEXT NOT NULL
    );

    CREATE TABLE IF NOT EXISTS backup_history (
      id TEXT PRIMARY KEY NOT NULL,
      uri TEXT NOT NULL,
      size_bytes INTEGER NOT NULL,
      checksum TEXT NOT NULL,
      created_at TEXT NOT NULL,
      kind TEXT NOT NULL
    );

    INSERT OR IGNORE INTO sync_metadata (id) VALUES (1);
  `);

  const categoryCount = await db.getFirstAsync<{ count: number }>('SELECT COUNT(*) as count FROM categories');
  if ((categoryCount?.count ?? 0) === 0) {
    for (const [index, [name, icon, color, type]] of DEFAULT_CATEGORIES.entries()) {
      await db.runAsync(
        `INSERT INTO categories (id, name, icon, color, type, is_custom, sort_order, updated_at)
         VALUES (?, ?, ?, ?, ?, 0, ?, ?)`,
        newId(),
        name,
        icon,
        color,
        type,
        index,
        nowIso(),
      );
    }
  }
}
