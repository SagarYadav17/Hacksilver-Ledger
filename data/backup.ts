import * as Crypto from 'expo-crypto';
import * as DocumentPicker from 'expo-document-picker';
import * as FileSystem from 'expo-file-system/legacy';
import * as Sharing from 'expo-sharing';
import type { SQLiteDatabase } from 'expo-sqlite';
import { gcm } from '@noble/ciphers/aes.js';
import { bytesToHex, bytesToUtf8, hexToBytes, utf8ToBytes } from '@noble/ciphers/utils.js';
import { hkdf } from '@noble/hashes/hkdf.js';
import { sha256 } from '@noble/hashes/sha2.js';
import { z } from 'zod';
import { newId, nowIso, type BackupRecord } from '@/domain/types';
import { getDatabaseKey } from './database';
import { pbkdf2Sha256 } from '@/lib/kdf';

const BACKUP_PREFIX = 'hacksilver-backup-';
const CHECKPOINT_DIR = `${FileSystem.documentDirectory}checkpoints/`;
const CHECKPOINTS_KEPT = 3;
export const PBKDF2_ITERATIONS = 200_000;
export const MIN_PASSPHRASE_LENGTH = 8;
export const BAD_PASSPHRASE = 'Wrong passphrase or damaged backup';
const BACKUP_AAD = utf8ToBytes('hacksilver-backup-v2');
const CHECKPOINT_AAD = utf8ToBytes('hacksilver-checkpoint-v1');

// Row schemas mirror data/schema.ts; restore inserts exactly these columns.
const text = z.string();
const id = z.string().min(1);
const optionalText = z.string().nullish();
const optionalId = z.string().min(1).nullish();
const int = z.number().int();
const num = z.number().finite();
const flag = z.union([z.literal(0), z.literal(1)]);
const transactionType = z.enum(['income', 'expense', 'transfer', 'adjustment']);

const rowSchemas = {
  categories: z.object({
    id,
    name: text,
    icon: text,
    color: text,
    type: z.enum(['income', 'expense', 'transfer']),
    is_custom: flag,
    is_archived: flag,
    sort_order: int,
    updated_at: text,
    deleted_at: optionalText,
  }),
  accounts: z.object({
    id,
    name: text,
    type: z.enum(['cash', 'bank', 'credit_card', 'other']),
    balance: num,
    updated_at: text,
    deleted_at: optionalText,
  }),
  loans: z.object({
    id,
    title: text,
    amount: num,
    interest_rate: num,
    tenure_months: int,
    type: z.enum(['given', 'taken']),
    start_date: text,
    emi_amount: num,
    amount_paid: num,
    is_closed: flag,
    notes: optionalText,
    updated_at: text,
    deleted_at: optionalText,
  }),
  recurring_transactions: z.object({
    id,
    title: text,
    amount: num,
    type: transactionType,
    category_id: id,
    account_id: optionalId,
    frequency: z.enum(['daily', 'monthly', 'quarterly', 'yearly']),
    start_date: text,
    next_due_date: text,
    is_active: flag,
    notes: optionalText,
    updated_at: text,
    deleted_at: optionalText,
  }),
  transactions: z.object({
    id,
    title: text,
    amount: num,
    date: text,
    type: transactionType,
    category_id: id,
    account_id: optionalId,
    transfer_account_id: optionalId,
    notes: optionalText,
    original_amount: num.nullish(),
    original_currency: optionalText,
    loan_id: optionalId,
    recurring_id: optionalId,
    updated_at: text,
    deleted_at: optionalText,
  }),
};

/** Parent tables first: insert order. */
const TABLES = ['categories', 'accounts', 'loans', 'recurring_transactions', 'transactions'] as const;
type TableName = (typeof TABLES)[number];

export const backupTablesSchema = z.object({
  categories: z.array(rowSchemas.categories),
  accounts: z.array(rowSchemas.accounts),
  loans: z.array(rowSchemas.loans),
  recurring_transactions: z.array(rowSchemas.recurring_transactions),
  transactions: z.array(rowSchemas.transactions),
});
export type BackupTables = z.infer<typeof backupTablesSchema>;

export const backupPayloadSchema = z.object({ createdAt: text, tables: backupTablesSchema });
export type BackupPayload = z.infer<typeof backupPayloadSchema>;

const hex = (bytes: number) => z.string().regex(new RegExp(`^[0-9a-f]{${bytes * 2}}$`));
const hexData = z.string().regex(/^(?:[0-9a-f]{2})+$/);
const cipherSchema = z.object({ name: z.literal('aes-256-gcm'), nonce: hex(12) });

export const encryptedBackupSchema = z.object({
  version: z.literal(2),
  createdAt: text,
  kdf: z.object({
    name: z.literal('pbkdf2-sha256'),
    iter: z.number().int().min(100_000).max(5_000_000),
    salt: hex(16),
  }),
  cipher: cipherSchema,
  data: hexData,
});
export type EncryptedBackup = z.infer<typeof encryptedBackupSchema>;

const legacyBackupSchema = z.object({
  version: z.literal(1),
  createdAt: text,
  checksum: z.string(),
  tables: z.record(z.string(), z.unknown()),
});

const checkpointSchema = z.object({
  version: z.literal(1),
  kind: z.literal('checkpoint'),
  createdAt: text,
  cipher: cipherSchema,
  data: hexData,
});

export type ParsedBackup =
  | { version: 2; createdAt: string; envelope: EncryptedBackup }
  | { version: 1; createdAt: string; payload: BackupPayload };

export function validatePayload(value: unknown): BackupPayload {
  const result = backupPayloadSchema.safeParse(value);
  if (!result.success) {
    const issue = result.error.issues[0];
    throw new Error(`Backup contains invalid data${issue ? ` at ${issue.path.join('.')}` : ''}`);
  }
  return result.data;
}

function seal(key: Uint8Array, aad: Uint8Array, plaintext: string) {
  const nonce = Crypto.getRandomBytes(12);
  return {
    cipher: { name: 'aes-256-gcm' as const, nonce: bytesToHex(nonce) },
    data: bytesToHex(gcm(key, nonce, aad).encrypt(utf8ToBytes(plaintext))),
  };
}

function open(key: Uint8Array, aad: Uint8Array, nonce: string, data: string): unknown {
  let plaintext: string;
  try {
    plaintext = bytesToUtf8(gcm(key, hexToBytes(nonce), aad).decrypt(hexToBytes(data)));
  } catch {
    throw new Error(BAD_PASSPHRASE);
  }
  return JSON.parse(plaintext);
}

const deriveKey = (passphrase: string, salt: Uint8Array, iter: number) =>
  pbkdf2Sha256(utf8ToBytes(passphrase.normalize('NFKC')), salt, iter);

export async function encryptBackup(
  payload: BackupPayload,
  passphrase: string,
  iter = PBKDF2_ITERATIONS,
): Promise<EncryptedBackup> {
  if (passphrase.length < MIN_PASSPHRASE_LENGTH)
    throw new Error(`Passphrase must be at least ${MIN_PASSPHRASE_LENGTH} characters`);
  const salt = Crypto.getRandomBytes(16);
  const key = await deriveKey(passphrase, salt, iter);
  return {
    version: 2,
    createdAt: payload.createdAt,
    kdf: { name: 'pbkdf2-sha256', iter, salt: bytesToHex(salt) },
    ...seal(key, BACKUP_AAD, JSON.stringify(payload)),
  };
}

export async function decryptBackup(envelope: EncryptedBackup, passphrase: string): Promise<BackupPayload> {
  const key = await deriveKey(passphrase, hexToBytes(envelope.kdf.salt), envelope.kdf.iter);
  return validatePayload(open(key, BACKUP_AAD, envelope.cipher.nonce, envelope.data));
}

/** Parses a backup file. v2 still needs `decryptBackup`; v1 is checksum-verified and validated here. */
export async function parseBackup(contents: string): Promise<ParsedBackup> {
  let json: unknown;
  try {
    json = JSON.parse(contents);
  } catch {
    throw new Error('This is not a Hacksilver backup file');
  }
  const v2 = encryptedBackupSchema.safeParse(json);
  if (v2.success) return { version: 2, createdAt: v2.data.createdAt, envelope: v2.data };
  const v1 = legacyBackupSchema.safeParse(json);
  if (!v1.success) throw new Error('This is not a Hacksilver backup file');
  const { version, createdAt, tables, checksum } = v1.data;
  const expected = await Crypto.digestStringAsync(
    Crypto.CryptoDigestAlgorithm.SHA256,
    JSON.stringify({ version, createdAt, tables }),
  );
  if (expected !== checksum) throw new Error('Backup integrity check failed');
  return { version: 1, createdAt, payload: validatePayload({ createdAt, tables }) };
}

async function readTables(db: SQLiteDatabase): Promise<Record<TableName, unknown[]>> {
  const tables = {} as Record<TableName, unknown[]>;
  for (const table of TABLES) tables[table] = await db.getAllAsync(`SELECT * FROM ${table}`);
  return tables;
}

/** Replaces all ledger tables atomically. Rows must already be validated. */
export async function replaceTables(db: SQLiteDatabase, tables: BackupTables): Promise<void> {
  await db.withTransactionAsync(async () => {
    for (const table of [...TABLES].reverse()) await db.runAsync(`DELETE FROM ${table}`);
    for (const table of TABLES) {
      const columns = Object.keys(rowSchemas[table].shape);
      const sql = `INSERT INTO ${table} (${columns.join(', ')}) VALUES (${columns.map(() => '?').join(', ')})`;
      for (const row of tables[table] as Array<Record<string, string | number | null | undefined>>)
        await db.runAsync(sql, ...columns.map((column) => row[column] ?? null));
    }
    // Restored rows must win the next sync; otherwise newer remote copies would silently undo the restore.
    const restoredAt = nowIso();
    for (const table of TABLES) await db.runAsync(`UPDATE ${table} SET updated_at = ?`, restoredAt);
  });
}

async function insertRecord(db: SQLiteDatabase, record: BackupRecord): Promise<void> {
  await db.runAsync(
    'INSERT INTO backup_history (id, uri, size_bytes, checksum, created_at, kind) VALUES (?, ?, ?, ?, ?, ?)',
    record.id,
    record.uri,
    record.sizeBytes,
    record.checksum,
    record.createdAt,
    record.kind,
  );
}

const describeFile = (contents: string) => {
  const bytes = utf8ToBytes(contents);
  return { sizeBytes: bytes.length, checksum: bytesToHex(sha256(bytes)) };
};

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

/** Removes exported files left in the cache; Android may still be reading the latest one when share resolves. */
export async function purgeExportedFiles(): Promise<void> {
  if (!FileSystem.cacheDirectory) return;
  const names = await FileSystem.readDirectoryAsync(FileSystem.cacheDirectory).catch(() => [] as string[]);
  await Promise.all(
    names
      .filter((name) => name.startsWith(BACKUP_PREFIX))
      .map((name) =>
        FileSystem.deleteAsync(`${FileSystem.cacheDirectory}${name}`, { idempotent: true }).catch(() => undefined),
      ),
  );
}

/** Encrypts the ledger with a passphrase and shares it; the file is purged on the next export or app start. */
export async function exportBackup(db: SQLiteDatabase, passphrase: string): Promise<BackupRecord> {
  if (!(await Sharing.isAvailableAsync())) throw new Error('Sharing is not available on this device');
  await purgeExportedFiles();
  const createdAt = nowIso();
  const tables = validatePayload({ createdAt, tables: await readTables(db) }).tables;
  const contents = JSON.stringify(await encryptBackup({ createdAt, tables }, passphrase));
  const uri = `${FileSystem.cacheDirectory}${BACKUP_PREFIX}${Date.now()}.json`;
  await FileSystem.writeAsStringAsync(uri, contents);
  await Sharing.shareAsync(uri, { mimeType: 'application/json', dialogTitle: 'Share your Hacksilver backup' });
  const record: BackupRecord = { id: newId(), uri: 'shared', ...describeFile(contents), createdAt, kind: 'export' };
  await insertRecord(db, record);
  return record;
}

/** Lets the user pick a backup file; returns null when cancelled. */
export async function pickBackup(): Promise<ParsedBackup | null> {
  const result = await DocumentPicker.getDocumentAsync({ type: 'application/json', copyToCacheDirectory: true });
  if (result.canceled) return null;
  const uri = result.assets[0].uri;
  try {
    return await parseBackup(await FileSystem.readAsStringAsync(uri));
  } finally {
    await FileSystem.deleteAsync(uri, { idempotent: true }).catch(() => undefined);
  }
}

// Separate subkey so the SQLCipher key is never used directly as an AES-GCM key.
const checkpointKey = async () =>
  hkdf(sha256, hexToBytes(await getDatabaseKey()), undefined, utf8ToBytes('hacksilver-checkpoint-key'), 32);

/** Encrypts the current ledger with the device database key and keeps the newest few checkpoints. */
export async function createCheckpoint(db: SQLiteDatabase): Promise<BackupRecord> {
  const createdAt = nowIso();
  const key = await checkpointKey();
  const contents = JSON.stringify({
    version: 1,
    kind: 'checkpoint',
    createdAt,
    ...seal(key, CHECKPOINT_AAD, JSON.stringify({ createdAt, tables: await readTables(db) })),
  });
  await FileSystem.makeDirectoryAsync(CHECKPOINT_DIR, { intermediates: true });
  const recordId = newId();
  const uri = `${CHECKPOINT_DIR}${Date.now()}-${recordId}.json`;
  await FileSystem.writeAsStringAsync(uri, contents);
  const record: BackupRecord = { id: recordId, uri, ...describeFile(contents), createdAt, kind: 'pre_restore' };
  await insertRecord(db, record);
  await pruneCheckpoints(db);
  return record;
}

export async function pruneCheckpoints(db: SQLiteDatabase, keep = CHECKPOINTS_KEPT): Promise<void> {
  const stale = await db.getAllAsync<{ id: string; uri: string }>(
    "SELECT id, uri FROM backup_history WHERE kind = 'pre_restore' ORDER BY created_at DESC, uri DESC LIMIT -1 OFFSET ?",
    keep,
  );
  for (const row of stale) {
    await FileSystem.deleteAsync(row.uri, { idempotent: true });
    await db.runAsync('DELETE FROM backup_history WHERE id = ?', row.id);
  }
}

/** Snapshots the current ledger, then replaces it with the validated payload. */
export async function restorePayload(db: SQLiteDatabase, payload: BackupPayload): Promise<void> {
  const { tables } = validatePayload(payload);
  await createCheckpoint(db);
  await replaceTables(db, tables);
}

export async function readCheckpoint(record: Pick<BackupRecord, 'uri'>): Promise<BackupPayload> {
  if (!record.uri.startsWith(CHECKPOINT_DIR)) throw new Error('Not a restore checkpoint');
  const parsed = checkpointSchema.safeParse(JSON.parse(await FileSystem.readAsStringAsync(record.uri)));
  if (!parsed.success) throw new Error('Checkpoint file is damaged');
  const key = await checkpointKey();
  return validatePayload(open(key, CHECKPOINT_AAD, parsed.data.cipher.nonce, parsed.data.data));
}

export async function restoreCheckpoint(db: SQLiteDatabase, record: BackupRecord): Promise<void> {
  if (record.kind !== 'pre_restore') throw new Error('Not a restore checkpoint');
  await restorePayload(db, await readCheckpoint(record));
}
