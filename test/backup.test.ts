import { beforeAll, describe, expect, mock, test } from 'bun:test';
import { createHash } from 'node:crypto';
import type { SQLiteDatabase } from 'expo-sqlite';
import { initializeDatabase } from '../data/schema';
import { MemoryDatabase } from './memory-db';

const files = new Map<string, string>();
mock.module('expo-file-system/legacy', () => ({
  documentDirectory: 'file:///docs/',
  cacheDirectory: 'file:///cache/',
  makeDirectoryAsync: async () => undefined,
  writeAsStringAsync: async (uri: string, contents: string) => void files.set(uri, contents),
  readAsStringAsync: async (uri: string) => {
    const contents = files.get(uri);
    if (contents === undefined) throw new Error(`missing ${uri}`);
    return contents;
  },
  deleteAsync: async (uri: string) => void files.delete(uri),
  getInfoAsync: async (uri: string) => ({ exists: files.has(uri) }),
  readDirectoryAsync: async (dir: string) =>
    [...files.keys()].filter((uri) => uri.startsWith(dir)).map((uri) => uri.slice(dir.length)),
}));
mock.module('expo-sharing', () => ({ isAvailableAsync: async () => true, shareAsync: async () => undefined }));
mock.module('expo-document-picker', () => ({ getDocumentAsync: async () => ({ canceled: true }) }));
mock.module('expo-sqlite', () => ({ defaultDatabaseDirectory: '/db' }));

type Backup = typeof import('../data/backup');
let backup: Backup;
beforeAll(async () => {
  backup = await import('../data/backup');
});

const ts = '2026-09-01T00:00:00.000Z';
const sampleTables = () => ({
  categories: [
    {
      id: 'c1',
      name: 'Food',
      icon: 'restaurant',
      color: '#fff',
      type: 'expense',
      is_custom: 1,
      is_archived: 0,
      sort_order: 0,
      updated_at: ts,
      deleted_at: null,
    },
  ],
  accounts: [{ id: 'a1', name: 'Main', type: 'bank', balance: 90, updated_at: ts, deleted_at: null }],
  loans: [],
  recurring_transactions: [],
  transactions: [
    {
      id: 't1',
      title: 'Lunch',
      amount: 10,
      date: ts,
      type: 'expense',
      category_id: 'c1',
      account_id: 'a1',
      transfer_account_id: null,
      notes: null,
      original_amount: null,
      original_currency: null,
      loan_id: null,
      recurring_id: null,
      updated_at: ts,
      deleted_at: null,
    },
  ],
});
const samplePayload = () => backup.validatePayload({ createdAt: ts, tables: sampleTables() });
const ITER = 100_000;

async function createDb() {
  const database = new MemoryDatabase();
  const db = database as unknown as SQLiteDatabase;
  await initializeDatabase(db);
  return db;
}

describe('encrypted backups', () => {
  test('round-trips through passphrase encryption', async () => {
    const envelope = await backup.encryptBackup(samplePayload(), 'correct horse', ITER);
    expect(envelope.version).toBe(2);
    expect(JSON.stringify(envelope)).not.toContain('Lunch');
    const parsed = await backup.parseBackup(JSON.stringify(envelope));
    expect(parsed.version).toBe(2);
    if (parsed.version !== 2) return;
    expect(await backup.decryptBackup(parsed.envelope, 'correct horse')).toEqual(samplePayload());
  });

  test('rejects a wrong passphrase', async () => {
    const envelope = await backup.encryptBackup(samplePayload(), 'correct horse', ITER);
    await expect(backup.decryptBackup(envelope, 'wrong horse')).rejects.toThrow(backup.BAD_PASSPHRASE);
  });

  test('rejects tampered ciphertext', async () => {
    const envelope = await backup.encryptBackup(samplePayload(), 'correct horse', ITER);
    const flipped = (Number.parseInt(envelope.data[0], 16) ^ 1).toString(16);
    const tampered = { ...envelope, data: flipped + envelope.data.slice(1) };
    await expect(backup.decryptBackup(tampered, 'correct horse')).rejects.toThrow(backup.BAD_PASSPHRASE);
  });

  test('rejects short passphrases and weak kdf parameters', async () => {
    await expect(backup.encryptBackup(samplePayload(), 'short')).rejects.toThrow();
    const envelope = await backup.encryptBackup(samplePayload(), 'correct horse', ITER);
    await expect(
      backup.parseBackup(JSON.stringify({ ...envelope, kdf: { ...envelope.kdf, iter: 1 } })),
    ).rejects.toThrow();
  });
});

describe('row validation', () => {
  test('rejects rows that do not match the schema', () => {
    const tables = sampleTables();
    (tables.transactions[0] as Record<string, unknown>).amount = 'lots';
    expect(() => backup.validatePayload({ createdAt: ts, tables })).toThrow(/transactions\.0\.amount/);
    const missing = sampleTables() as Record<string, unknown>;
    delete missing.accounts;
    expect(() => backup.validatePayload({ createdAt: ts, tables: missing })).toThrow();
    const badEnum = sampleTables();
    badEnum.accounts[0].type = 'offshore';
    expect(() => backup.validatePayload({ createdAt: ts, tables: badEnum })).toThrow();
  });

  test('strips unknown columns', () => {
    const tables = sampleTables();
    (tables.accounts[0] as Record<string, unknown>).evil = "'; DROP TABLE accounts; --";
    expect(backup.validatePayload({ createdAt: ts, tables }).tables.accounts[0]).not.toHaveProperty('evil');
  });
});

describe('v1 backups', () => {
  const v1 = <T>(tables: T) => {
    const checksum = createHash('sha256')
      .update(JSON.stringify({ version: 1, createdAt: ts, tables }))
      .digest('hex');
    return { version: 1, createdAt: ts, checksum, tables };
  };

  test('accepts a valid checksum and validates rows', async () => {
    const parsed = await backup.parseBackup(JSON.stringify(v1(sampleTables())));
    expect(parsed.version).toBe(1);
    if (parsed.version === 1) expect(parsed.payload.tables.transactions).toHaveLength(1);
  });

  test('rejects a checksum mismatch', async () => {
    const file = v1(sampleTables());
    file.tables.accounts[0].balance = 1_000_000;
    await expect(backup.parseBackup(JSON.stringify(file))).rejects.toThrow('integrity');
  });

  test('rejects invalid rows even with a matching checksum', async () => {
    const tables = sampleTables();
    (tables.categories[0] as Record<string, unknown>).is_custom = 'yes';
    await expect(backup.parseBackup(JSON.stringify(v1(tables)))).rejects.toThrow('invalid data');
  });
});

describe('restore and checkpoints', () => {
  test('restorePayload checkpoints current data and restoreCheckpoint brings it back', async () => {
    const db = await createDb();
    const categoryColumns = 'id, name, icon, color, type, is_custom, is_archived, sort_order, deleted_at';
    const originalCategories = await db.getAllAsync(`SELECT ${categoryColumns} FROM categories ORDER BY id`);
    const before = new Date().toISOString();
    await backup.restorePayload(db, samplePayload());
    const stamps = await db.getAllAsync<{ updated_at: string }>('SELECT updated_at FROM transactions');
    expect(stamps.every((row) => row.updated_at >= before)).toBe(true);
    expect(await db.getAllAsync('SELECT id FROM transactions')).toEqual([{ id: 't1' }]);
    const [checkpoint] = (await backup.getBackupHistory(db)).filter((record) => record.kind === 'pre_restore');
    expect(checkpoint.uri.startsWith('file:///docs/checkpoints/')).toBe(true);
    expect(files.get(checkpoint.uri)).not.toContain('Food & dining');
    await backup.restoreCheckpoint(db, checkpoint);
    expect(await db.getAllAsync(`SELECT ${categoryColumns} FROM categories ORDER BY id`)).toEqual(originalCategories);
    expect(await db.getAllAsync('SELECT id FROM transactions')).toEqual([]);
  });

  test('keeps only the three newest checkpoints', async () => {
    const db = await createDb();
    const existing = new Set(files.keys());
    for (let index = 0; index < 5; index += 1) {
      await backup.createCheckpoint(db);
      await Bun.sleep(2);
    }
    const checkpoints = (await backup.getBackupHistory(db)).filter((record) => record.kind === 'pre_restore');
    expect(checkpoints).toHaveLength(3);
    const stored = [...files.keys()].filter((uri) => !existing.has(uri) && uri.includes('/checkpoints/'));
    expect(stored.toSorted()).toEqual(checkpoints.map((record) => record.uri).toSorted());
  });

  test('failed inserts roll back and leave the ledger intact', async () => {
    const db = await createDb();
    const tables = sampleTables();
    tables.transactions[0].category_id = 'missing';
    const before = await db.getAllAsync('SELECT id FROM categories ORDER BY id');
    await expect(backup.replaceTables(db, backup.validatePayload({ createdAt: ts, tables }).tables)).rejects.toThrow();
    expect(await db.getAllAsync('SELECT id FROM categories ORDER BY id')).toEqual(before);
  });

  test('export keeps the shared file until the next export purges it', async () => {
    const db = await createDb();
    const cached = () => [...files.keys()].filter((uri) => uri.startsWith('file:///cache/'));
    const record = await backup.exportBackup(db, 'correct horse');
    expect(record.kind).toBe('export');
    expect(record.sizeBytes).toBeGreaterThan(0);
    expect(cached()).toHaveLength(1);
    const first = cached()[0];
    await Bun.sleep(2);
    await backup.exportBackup(db, 'correct horse');
    expect(cached()).toHaveLength(1);
    expect(cached()[0]).not.toBe(first);
    await backup.purgeExportedFiles();
    expect(cached()).toHaveLength(0);
  });
});
