import * as Crypto from 'expo-crypto';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import type { SQLiteDatabase } from 'expo-sqlite';
import { newId, nowIso, type BackupRecord } from '@/domain/types';

const TABLES = ['categories', 'accounts', 'loans', 'recurring_transactions', 'transactions'] as const;
const BACKUP_PREFIX = 'hacksilver-backup-';

export interface LedgerBackup {
  version: 1;
  createdAt: string;
  checksum: string;
  tables: Record<string, unknown[]>;
}

export async function getBackupHistory(db: SQLiteDatabase): Promise<BackupRecord[]> {
  const rows = await db.getAllAsync<Record<string, unknown>>(
    'SELECT id, uri, size_bytes, checksum, created_at, kind FROM backup_history ORDER BY created_at DESC',
  );
  return rows.map((row) => ({
    id: String(row.id),
    uri: String(row.uri),
    sizeBytes: Number(row.size_bytes),
    checksum: String(row.checksum),
    createdAt: String(row.created_at),
    kind: row.kind === 'pre_restore' ? 'pre_restore' : 'export',
  }));
}

export async function exportBackup(db: SQLiteDatabase): Promise<BackupRecord> {
  const tables: Record<string, Record<string, unknown>[]> = {};
  for (const table of TABLES) tables[table] = await db.getAllAsync<Record<string, unknown>>(`SELECT * FROM ${table}`);
  const createdAt = nowIso();
  const payload = JSON.stringify({ version: 1, createdAt, tables });
  const checksum = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, payload);
  const backup: LedgerBackup = { version: 1, createdAt, checksum, tables };
  const uri = `${FileSystem.cacheDirectory}${BACKUP_PREFIX}${Date.now()}.json`;
  await FileSystem.writeAsStringAsync(uri, JSON.stringify(backup, null, 2));
  if (await Sharing.isAvailableAsync())
    await Sharing.shareAsync(uri, { mimeType: 'application/json', dialogTitle: 'Share your Hacksilver backup' });
  const record = {
    id: newId(),
    uri,
    sizeBytes: payload.length,
    checksum,
    createdAt: backup.createdAt,
    kind: 'export' as const,
  };
  await db.runAsync(
    'INSERT INTO backup_history (id, uri, size_bytes, checksum, created_at, kind) VALUES (?, ?, ?, ?, ?, ?)',
    record.id,
    record.uri,
    record.sizeBytes,
    record.checksum,
    record.createdAt,
    record.kind,
  );
  return record;
}

export async function restoreBackup(db: SQLiteDatabase): Promise<void> {
  const result = await DocumentPicker.getDocumentAsync({ type: 'application/json', copyToCacheDirectory: true });
  if (result.canceled) return;
  const text = await FileSystem.readAsStringAsync(result.assets[0].uri);
  const backup = JSON.parse(text) as LedgerBackup;
  if (backup.version !== 1 || !backup.tables || !backup.checksum) throw new Error('Invalid Hacksilver backup');
  const content = JSON.stringify({ version: backup.version, createdAt: backup.createdAt, tables: backup.tables });
  const checksum = await Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, content);
  if (checksum !== backup.checksum) throw new Error('Backup integrity check failed');
  await db.withTransactionAsync(async () => {
    for (const table of TABLES.toReversed()) await db.runAsync(`DELETE FROM ${table}`);
    for (const row of (backup.tables.categories ?? []) as Array<Record<string, unknown>>)
      await db.runAsync(
        'INSERT INTO categories (id, name, icon, color, type, is_custom, is_archived, sort_order, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        row.id as string,
        row.name as string,
        row.icon as string,
        row.color as string,
        row.type as string,
        row.is_custom as number,
        row.is_archived as number,
        row.sort_order as number,
        row.updated_at as string,
        row.deleted_at as string | null,
      );
    for (const row of (backup.tables.accounts ?? []) as Array<Record<string, unknown>>)
      await db.runAsync(
        'INSERT INTO accounts (id, name, type, balance, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?)',
        row.id as string,
        row.name as string,
        row.type as string,
        row.balance as number,
        row.updated_at as string,
        row.deleted_at as string | null,
      );
    for (const row of (backup.tables.loans ?? []) as Array<Record<string, unknown>>)
      await db.runAsync(
        'INSERT INTO loans (id, title, amount, interest_rate, tenure_months, type, start_date, emi_amount, amount_paid, is_closed, notes, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        row.id as string,
        row.title as string,
        row.amount as number,
        row.interest_rate as number,
        row.tenure_months as number,
        row.type as string,
        row.start_date as string,
        row.emi_amount as number,
        row.amount_paid as number,
        row.is_closed as number,
        row.notes as string | null,
        row.updated_at as string,
        row.deleted_at as string | null,
      );
    for (const row of (backup.tables.recurring_transactions ?? []) as Array<Record<string, unknown>>)
      await db.runAsync(
        'INSERT INTO recurring_transactions (id, title, amount, type, category_id, account_id, frequency, start_date, next_due_date, is_active, notes, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        row.id as string,
        row.title as string,
        row.amount as number,
        row.type as string,
        row.category_id as string,
        row.account_id as string | null,
        row.frequency as string,
        row.start_date as string,
        row.next_due_date as string,
        row.is_active as number,
        row.notes as string | null,
        row.updated_at as string,
        row.deleted_at as string | null,
      );
    for (const row of (backup.tables.transactions ?? []) as Array<Record<string, unknown>>)
      await db.runAsync(
        'INSERT INTO transactions (id, title, amount, date, type, category_id, account_id, transfer_account_id, notes, original_amount, original_currency, loan_id, recurring_id, updated_at, deleted_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        row.id as string,
        row.title as string,
        row.amount as number,
        row.date as string,
        row.type as string,
        row.category_id as string,
        row.account_id as string | null,
        row.transfer_account_id as string | null,
        row.notes as string | null,
        row.original_amount as number | null,
        row.original_currency as string | null,
        row.loan_id as string | null,
        row.recurring_id as string | null,
        row.updated_at as string,
        row.deleted_at as string | null,
      );
  });
}
