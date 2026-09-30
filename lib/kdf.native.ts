import { pbkdf2 } from 'react-native-quick-crypto';

/** Native PBKDF2-HMAC-SHA256; pure-JS PBKDF2 takes tens of seconds on Hermes at these iteration counts. */
export function pbkdf2Sha256(password: Uint8Array, salt: Uint8Array, iterations: number, dkLen = 32) {
  return new Promise<Uint8Array>((resolve, reject) =>
    pbkdf2(password, salt, iterations, dkLen, 'sha256', (error, key) =>
      error || !key ? reject(error ?? new Error('Key derivation failed')) : resolve(new Uint8Array(key)),
    ),
  );
}
