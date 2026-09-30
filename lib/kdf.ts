import { pbkdf2Async } from '@noble/hashes/pbkdf2.js';
import { sha256 } from '@noble/hashes/sha2.js';

/** PBKDF2-HMAC-SHA256. Pure JS for web/tests; kdf.native.ts uses native code on iOS/Android. */
export function pbkdf2Sha256(password: Uint8Array, salt: Uint8Array, iterations: number, dkLen = 32) {
  return pbkdf2Async(sha256, password, salt, { c: iterations, dkLen });
}
