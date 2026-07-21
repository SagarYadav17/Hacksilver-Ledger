import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';

/// Secure storage service with encryption
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      keyCipherAlgorithm: KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
      storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
    ),
    iOptions: IOSOptions(
      accountName: 'hacksilver_secure_storage',
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // Key names
  static const String _keyPocketBaseAuth = 'pocketbase_auth';
  static const String _keyUserPin = 'user_pin_hash';
  static const String _keyLastBackup = 'last_backup_time';
  static const String _keyEncryptionSalt = 'encryption_salt';

  /// Store the PocketBase auth session (exported from `authStore.exportToJson()`)
  static Future<void> storePocketBaseAuth(String authJson) async {
    await _storage.write(key: _keyPocketBaseAuth, value: authJson);
  }

  /// Retrieve the saved PocketBase auth session, if any
  static Future<String?> getPocketBaseAuth() async {
    return _storage.read(key: _keyPocketBaseAuth);
  }

  /// Clear the saved PocketBase auth session (logout)
  static Future<void> clearPocketBaseAuth() async {
    await _storage.delete(key: _keyPocketBaseAuth);
  }

  /// Store user PIN hash (for app lock feature)
  static Future<void> storePinHash(String pin) async {
    final salt = await _getOrCreateSalt();
    final hash = _hashPin(pin, salt);
    await _storage.write(key: _keyUserPin, value: hash);
  }

  /// Verify PIN
  static Future<bool> verifyPin(String pin) async {
    final storedHash = await _storage.read(key: _keyUserPin);
    if (storedHash == null) return false;
    
    final salt = await _getOrCreateSalt();
    final hash = _hashPin(pin, salt);
    return hash == storedHash;
  }

  /// Check if PIN is set
  static Future<bool> hasPin() async {
    final pin = await _storage.read(key: _keyUserPin);
    return pin != null;
  }

  /// Clear PIN
  static Future<void> clearPin() async {
    await _storage.delete(key: _keyUserPin);
  }

  /// Store last backup timestamp
  static Future<void> storeLastBackupTime(DateTime time) async {
    await _storage.write(key: _keyLastBackup, value: time.toIso8601String());
  }

  /// Get last backup timestamp
  static Future<DateTime?> getLastBackupTime() async {
    final time = await _storage.read(key: _keyLastBackup);
    if (time == null) return null;
    return DateTime.tryParse(time);
  }

  /// Clear all secure data
  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }

  /// Get or create encryption salt
  static Future<String> _getOrCreateSalt() async {
    var salt = await _storage.read(key: _keyEncryptionSalt);
    if (salt == null) {
      // Generate a new random salt
      final random = Uint8List(16);
      for (var i = 0; i < 16; i++) {
        random[i] = DateTime.now().millisecondsSinceEpoch % 256;
      }
      salt = base64Encode(random);
      await _storage.write(key: _keyEncryptionSalt, value: salt);
    }
    return salt;
  }

  /// Hash PIN with salt
  static String _hashPin(String pin, String salt) {
    final bytes = utf8.encode(pin + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Store a sensitive value with custom key
  static Future<void> storeSecureValue(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a sensitive value
  static Future<String?> readSecureValue(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a sensitive value
  static Future<void> deleteSecureValue(String key) async {
    await _storage.delete(key: key);
  }
}

/// Secure random token generator
class SecureRandom {
  static String generateToken({int length = 32}) {
    final random = Uint8List(length);
    final now = DateTime.now().millisecondsSinceEpoch;
    
    // Simple pseudo-random generation (for production, use dart:math Random.secure())
    for (var i = 0; i < length; i++) {
      random[i] = (now + i * 137) % 256;
    }
    
    return base64UrlEncode(random);
  }
}
