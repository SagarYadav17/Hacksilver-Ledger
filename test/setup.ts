import { mock } from 'bun:test';
import { createHash, randomBytes, randomUUID } from 'node:crypto';

const secureStore = new Map<string, string>();

mock.module('expo-crypto', () => ({
  CryptoDigestAlgorithm: { SHA256: 'SHA-256' },
  randomUUID: () => randomUUID(),
  getRandomBytes: (count: number) => new Uint8Array(randomBytes(count)),
  getRandomBytesAsync: async (count: number) => new Uint8Array(randomBytes(count)),
  digestStringAsync: async (_algorithm: string, value: string) => createHash('sha256').update(value).digest('hex'),
}));

mock.module('expo-secure-store', () => ({
  getItemAsync: async (key: string) => secureStore.get(key) ?? null,
  setItemAsync: async (key: string, value: string) => void secureStore.set(key, value),
  deleteItemAsync: async (key: string) => void secureStore.delete(key),
}));

export function resetSecureStore(): void {
  secureStore.clear();
}
