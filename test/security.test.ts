import { beforeEach, describe, expect, test } from 'bun:test';
import { createHash } from 'node:crypto';
import * as SecureStore from 'expo-secure-store';
import {
  BASE_LOCKOUT_MS,
  clearPin,
  getLockoutState,
  isAppLockEnabled,
  isBiometricEnabled,
  lockoutDuration,
  MAX_LOCKOUT_MS,
  PIN_ITERATIONS,
  setBiometricEnabled,
  setPin,
  verifyPin,
} from '../data/security';
import { resetSecureStore } from './setup';

const PIN_KEY = 'hacksilver.security.pin-hash';

beforeEach(() => resetSecureStore());

async function fail(times: number, now: number) {
  let result;
  for (let i = 0; i < times; i++) result = await verifyPin('0000', now);
  return result;
}

describe('pin hashing', () => {
  test('stores a salted PBKDF2 record and verifies it', async () => {
    await setPin('1234');
    const record = JSON.parse((await SecureStore.getItemAsync(PIN_KEY))!);
    expect(record).toMatchObject({ v: 2, iter: PIN_ITERATIONS });
    expect(record.salt).toMatch(/^[0-9a-f]{32}$/);
    expect(record.hash).toMatch(/^[0-9a-f]{64}$/);
    expect(await isAppLockEnabled()).toBe(true);
    expect(await verifyPin('1234')).toEqual({ ok: true });
  });

  test('uses a fresh salt per PIN', async () => {
    await setPin('1234');
    const first = await SecureStore.getItemAsync(PIN_KEY);
    await setPin('1234');
    expect(await SecureStore.getItemAsync(PIN_KEY)).not.toBe(first);
  });

  test('rejects a wrong PIN', async () => {
    await setPin('1234');
    expect(await verifyPin('4321')).toEqual({ ok: false, lockedUntil: null });
    expect((await getLockoutState()).failedAttempts).toBe(1);
  });

  test('upgrades a legacy SHA-256 hash on success', async () => {
    const legacy = createHash('sha256').update('hacksilver:2468').digest('hex');
    await SecureStore.setItemAsync(PIN_KEY, legacy);
    expect((await verifyPin('1111')).ok).toBe(false);
    expect(await SecureStore.getItemAsync(PIN_KEY)).toBe(legacy);
    expect(await verifyPin('2468')).toEqual({ ok: true });
    expect(JSON.parse((await SecureStore.getItemAsync(PIN_KEY))!).v).toBe(2);
    expect(await verifyPin('2468')).toEqual({ ok: true });
  });

  test('clearPin removes PIN, lock and biometric', async () => {
    await setPin('1234');
    await setBiometricEnabled(true);
    await verifyPin('0000');
    await clearPin();
    expect(await SecureStore.getItemAsync(PIN_KEY)).toBeNull();
    expect(await isAppLockEnabled()).toBe(false);
    expect(await isBiometricEnabled()).toBe(false);
    expect(await getLockoutState()).toEqual({ failedAttempts: 0, lockoutUntil: 0 });
    expect((await verifyPin('1234')).ok).toBe(false);
  });
});

describe('backoff', () => {
  test('lockout durations double and cap', () => {
    expect([1, 5, 6, 7, 8].map(lockoutDuration)).toEqual([0, 0, 30_000, 60_000, 120_000]);
    expect(lockoutDuration(100)).toBe(MAX_LOCKOUT_MS);
  });

  test('first five failures are free, sixth locks out', async () => {
    await setPin('1234');
    const now = 1_000_000;
    expect(await fail(5, now)).toEqual({ ok: false, lockedUntil: null });
    expect(await fail(1, now)).toEqual({ ok: false, lockedUntil: now + BASE_LOCKOUT_MS });
    expect(await getLockoutState()).toEqual({ failedAttempts: 6, lockoutUntil: now + BASE_LOCKOUT_MS });
  });

  test('refuses even the correct PIN while locked out', async () => {
    await setPin('1234');
    const now = 1_000_000;
    await fail(6, now);
    expect(await verifyPin('1234', now + 1_000)).toEqual({ ok: false, lockedUntil: now + BASE_LOCKOUT_MS });
    expect((await getLockoutState()).failedAttempts).toBe(6);
  });

  test('further failures double the lockout', async () => {
    await setPin('1234');
    const now = 1_000_000;
    await fail(6, now);
    const later = now + BASE_LOCKOUT_MS;
    expect(await verifyPin('0000', later)).toEqual({ ok: false, lockedUntil: later + 2 * BASE_LOCKOUT_MS });
  });

  test('success after lockout resets attempts', async () => {
    await setPin('1234');
    const now = 1_000_000;
    await fail(6, now);
    expect(await verifyPin('1234', now + BASE_LOCKOUT_MS)).toEqual({ ok: true });
    expect(await getLockoutState()).toEqual({ failedAttempts: 0, lockoutUntil: 0 });
  });
});
