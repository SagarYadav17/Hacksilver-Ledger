import * as Crypto from 'expo-crypto';
import * as FileSystem from 'expo-file-system/legacy';
import * as SecureStore from 'expo-secure-store';
import * as SQLite from 'expo-sqlite';
import type { SQLiteDatabase } from 'expo-sqlite';
import { bytesToHex } from '@noble/hashes/utils.js';
import { initializeDatabase } from './schema';

export const DB_NAME = 'hacksilver_ledger_v2.db';
export const LEGACY_DB_NAME = 'hacksilver_ledger.db';
const KEY_NAME = 'hacksilver.db.key';
const isWeb = process.env.EXPO_OS === 'web';

let keyPromise: Promise<string> | null = null;
let preparePromise: Promise<void> | null = null;

/** 32-byte SQLCipher key (hex), generated once and kept in the device keystore. */
export function getDatabaseKey(): Promise<string> {
  keyPromise ??= (async () => {
    const existing = await SecureStore.getItemAsync(KEY_NAME);
    if (existing) {
      if (!/^[0-9a-f]{64}$/.test(existing)) throw new Error('Stored database key is corrupted');
      return existing;
    }
    const key = bytesToHex(Crypto.getRandomBytes(32));
    // AFTER_FIRST_UNLOCK so background sync can open the ledger while the device is locked.
    await SecureStore.setItemAsync(KEY_NAME, key, {
      keychainAccessible: SecureStore.AFTER_FIRST_UNLOCK_THIS_DEVICE_ONLY,
    });
    return key;
  })().catch((error) => {
    keyPromise = null;
    throw error;
  });
  return keyPromise;
}

const keyStatement = (key: string) => `PRAGMA key = "x'${key}'"`;

/** Must run before any other statement on a freshly opened connection. */
export async function applyKey(db: SQLiteDatabase): Promise<void> {
  if (isWeb) return;
  await db.execAsync(keyStatement(await getDatabaseKey()));
}

const databasePath = (name: string) => `${String(SQLite.defaultDatabaseDirectory).replace(/\/+$/, '')}/${name}`;
const fileExists = async (name: string) => (await FileSystem.getInfoAsync(`file://${databasePath(name)}`)).exists;

// deleteDatabaseAsync only removes the main file; plaintext WAL/SHM leftovers must go too.
async function removeDatabaseFiles(name: string): Promise<void> {
  for (const suffix of ['', '-wal', '-shm', '-journal'])
    await FileSystem.deleteAsync(`file://${databasePath(name)}${suffix}`, { idempotent: true });
}

async function countTransactions(db: SQLiteDatabase): Promise<number> {
  const table = await db.getFirstAsync<{ name: string }>(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = 'transactions'",
  );
  if (!table) return 0;
  return (await db.getFirstAsync<{ count: number }>('SELECT count(*) AS count FROM transactions'))?.count ?? 0;
}

async function migrateLegacyDatabase(): Promise<void> {
  if (!(await fileExists(LEGACY_DB_NAME)) || (await fileExists(DB_NAME))) return;
  const key = await getDatabaseKey();
  try {
    const legacy = await SQLite.openDatabaseAsync(LEGACY_DB_NAME);
    let expected: number;
    try {
      expected = await countTransactions(legacy);
      await legacy.execAsync(`ATTACH DATABASE '${databasePath(DB_NAME).replaceAll("'", "''")}' AS enc KEY "x'${key}'"`);
      await legacy.getFirstAsync("SELECT sqlcipher_export('enc')");
      await legacy.execAsync('DETACH DATABASE enc');
      await legacy.execAsync('PRAGMA wal_checkpoint(TRUNCATE)');
    } finally {
      await legacy.closeAsync();
    }
    const encrypted = await SQLite.openDatabaseAsync(DB_NAME);
    try {
      await encrypted.execAsync(keyStatement(key));
      const actual = await countTransactions(encrypted);
      if (actual !== expected) throw new Error(`Encrypted copy has ${actual} of ${expected} transactions`);
    } finally {
      await encrypted.closeAsync();
    }
  } catch (error) {
    await removeDatabaseFiles(DB_NAME).catch(() => undefined);
    throw error;
  }
  await removeDatabaseFiles(LEGACY_DB_NAME);
}

/** One-time migration of the plaintext ledger into the SQLCipher database. Safe to call repeatedly. */
export function prepareDatabase(): Promise<void> {
  if (isWeb) return Promise.resolve();
  preparePromise ??= migrateLegacyDatabase().catch((error) => {
    preparePromise = null;
    throw error;
  });
  return preparePromise;
}

/** Opens a dedicated keyed connection outside the React tree (background tasks). Caller closes it. */
export async function openLedgerDatabase(): Promise<SQLiteDatabase> {
  await prepareDatabase();
  const db = await SQLite.openDatabaseAsync(DB_NAME, { useNewConnection: true });
  await applyKey(db);
  await initializeDatabase(db);
  return db;
}
