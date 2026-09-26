import * as Crypto from 'expo-crypto';
import * as SecureStore from 'expo-secure-store';

const PIN_KEY = 'hacksilver.security.pin-hash';
const LOCK_KEY = 'hacksilver.security.app-lock';

export async function hashPin(pin: string): Promise<string> {
  return Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, `hacksilver:${pin}`);
}

export async function setPin(pin: string): Promise<void> {
  await SecureStore.setItemAsync(PIN_KEY, await hashPin(pin));
  await SecureStore.setItemAsync(LOCK_KEY, 'true');
}

export async function verifyPin(pin: string): Promise<boolean> {
  const expected = await SecureStore.getItemAsync(PIN_KEY);
  return Boolean(expected && expected === (await hashPin(pin)));
}

export async function clearPin(): Promise<void> {
  await SecureStore.deleteItemAsync(PIN_KEY);
  await SecureStore.setItemAsync(LOCK_KEY, 'false');
}

export async function isAppLockEnabled(): Promise<boolean> {
  return (await SecureStore.getItemAsync(LOCK_KEY)) === 'true';
}
