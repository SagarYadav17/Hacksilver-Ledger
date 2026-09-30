import * as Crypto from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';
import { sha256 } from '@noble/hashes/sha2.js';
import { bytesToHex, hexToBytes, utf8ToBytes } from '@noble/hashes/utils.js';
import { pbkdf2Sha256 } from '@/lib/kdf';

const PIN_KEY = 'hacksilver.security.pin-hash';
const LOCK_KEY = 'hacksilver.security.app-lock';
const BIOMETRIC_KEY = 'hacksilver.security.biometric';
const ATTEMPTS_KEY = 'hacksilver.security.failed-attempts';
const LOCKOUT_KEY = 'hacksilver.security.lockout-until';

export const PIN_ITERATIONS = 60_000;
export const FREE_ATTEMPTS = 5;
export const BASE_LOCKOUT_MS = 30_000;
export const MAX_LOCKOUT_MS = 15 * 60_000;

export type PinRecord = { v: 2; salt: string; iter: number; hash: string };
export type LockoutState = { failedAttempts: number; lockoutUntil: number };
export type VerifyResult = { ok: true } | { ok: false; lockedUntil: number | null };

const listeners = new Set<() => void>();

export function subscribeSecurity(listener: () => void): () => void {
  listeners.add(listener);
  return () => void listeners.delete(listener);
}

function notify() {
  listeners.forEach((listener) => listener());
}

export async function hashPin(
  pin: string,
  salt: Uint8Array = Crypto.getRandomBytes(16),
  iter = PIN_ITERATIONS,
): Promise<PinRecord> {
  const hash = await pbkdf2Sha256(utf8ToBytes(pin), salt, iter);
  return { v: 2, salt: bytesToHex(salt), iter, hash: bytesToHex(hash) };
}

export function timingSafeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a[i] ^ b[i];
  return diff === 0;
}

function parseRecord(stored: string): PinRecord | null {
  try {
    const record = JSON.parse(stored) as PinRecord;
    return record?.v === 2 ? record : null;
  } catch {
    return null;
  }
}

async function matches(pin: string, stored: string): Promise<{ ok: boolean; legacy: boolean }> {
  const record = parseRecord(stored);
  if (record) {
    const { hash } = await hashPin(pin, hexToBytes(record.salt), record.iter);
    return { ok: timingSafeEqual(hexToBytes(hash), hexToBytes(record.hash)), legacy: false };
  }
  if (!/^[0-9a-f]{64}$/i.test(stored)) return { ok: false, legacy: true };
  const legacy = sha256(utf8ToBytes(`hacksilver:${pin}`));
  return { ok: timingSafeEqual(legacy, hexToBytes(stored.toLowerCase())), legacy: true };
}

export function lockoutDuration(failedAttempts: number): number {
  if (failedAttempts <= FREE_ATTEMPTS) return 0;
  return Math.min(BASE_LOCKOUT_MS * 2 ** (failedAttempts - FREE_ATTEMPTS - 1), MAX_LOCKOUT_MS);
}

export async function getLockoutState(): Promise<LockoutState> {
  const [attempts, until] = await Promise.all([
    SecureStore.getItemAsync(ATTEMPTS_KEY),
    SecureStore.getItemAsync(LOCKOUT_KEY),
  ]);
  return { failedAttempts: Number(attempts) || 0, lockoutUntil: Number(until) || 0 };
}

export async function resetFailedAttempts(): Promise<void> {
  await SecureStore.deleteItemAsync(ATTEMPTS_KEY);
  await SecureStore.deleteItemAsync(LOCKOUT_KEY);
}

async function recordFailure(now: number): Promise<number | null> {
  const failedAttempts = (await getLockoutState()).failedAttempts + 1;
  const duration = lockoutDuration(failedAttempts);
  await SecureStore.setItemAsync(ATTEMPTS_KEY, String(failedAttempts));
  if (!duration) return null;
  await SecureStore.setItemAsync(LOCKOUT_KEY, String(now + duration));
  return now + duration;
}

export async function setPin(pin: string): Promise<void> {
  await SecureStore.setItemAsync(PIN_KEY, JSON.stringify(await hashPin(pin)));
  await SecureStore.setItemAsync(LOCK_KEY, 'true');
  await resetFailedAttempts();
  notify();
}

export async function verifyPin(pin: string, now = Date.now()): Promise<VerifyResult> {
  const { lockoutUntil } = await getLockoutState();
  if (lockoutUntil > now) return { ok: false, lockedUntil: lockoutUntil };
  const stored = await SecureStore.getItemAsync(PIN_KEY);
  if (!stored) return { ok: false, lockedUntil: null };
  const { ok, legacy } = await matches(pin, stored);
  if (!ok) return { ok: false, lockedUntil: await recordFailure(now) };
  if (legacy) await SecureStore.setItemAsync(PIN_KEY, JSON.stringify(await hashPin(pin)));
  await resetFailedAttempts();
  return { ok: true };
}

export async function clearPin(): Promise<void> {
  await SecureStore.deleteItemAsync(PIN_KEY);
  await SecureStore.setItemAsync(LOCK_KEY, 'false');
  await SecureStore.deleteItemAsync(BIOMETRIC_KEY);
  await resetFailedAttempts();
  notify();
}

export async function isAppLockEnabled(): Promise<boolean> {
  return (await SecureStore.getItemAsync(LOCK_KEY)) === 'true';
}

export async function isBiometricEnabled(): Promise<boolean> {
  return (await SecureStore.getItemAsync(BIOMETRIC_KEY)) === 'true';
}

export async function setBiometricEnabled(enabled: boolean): Promise<void> {
  if (enabled) await SecureStore.setItemAsync(BIOMETRIC_KEY, 'true');
  else await SecureStore.deleteItemAsync(BIOMETRIC_KEY);
  notify();
}
