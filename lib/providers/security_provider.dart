import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/secure_storage_service.dart';

class SecurityProvider with ChangeNotifier {
  static const String _keyHideBalances = 'hide_balances';
  static const String _keyAppLockEnabled = 'app_lock_enabled';

  bool _hideBalances = false;
  bool _appLockEnabled = false;
  bool _hasPin = false;
  bool _isUnlocked = false;
  bool _isLoading = true;

  bool get hideBalances => _hideBalances;
  bool get appLockEnabled => _appLockEnabled;
  bool get hasPin => _hasPin;
  bool get isUnlocked => _isUnlocked;
  bool get isLoading => _isLoading;
  bool get shouldShowLock => _appLockEnabled && _hasPin && !_isUnlocked;

  SecurityProvider() {
    initialize();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _hideBalances = prefs.getBool(_keyHideBalances) ?? false;
    _appLockEnabled = prefs.getBool(_keyAppLockEnabled) ?? false;
    _hasPin = await SecureStorageService.hasPin();
    _isUnlocked = !_appLockEnabled || !_hasPin;
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setHideBalances(bool value) async {
    _hideBalances = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHideBalances, value);
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    await SecureStorageService.storePinHash(pin);
    _hasPin = true;
    _appLockEnabled = true;
    _isUnlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, true);
    notifyListeners();
  }

  Future<bool> unlock(String pin) async {
    final ok = await SecureStorageService.verifyPin(pin);
    if (ok) {
      _isUnlocked = true;
      notifyListeners();
    }
    return ok;
  }

  Future<void> setAppLockEnabled(bool value) async {
    _appLockEnabled = value && _hasPin;
    _isUnlocked = !_appLockEnabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, _appLockEnabled);
    notifyListeners();
  }

  Future<void> clearPin() async {
    await SecureStorageService.clearPin();
    _hasPin = false;
    _appLockEnabled = false;
    _isUnlocked = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAppLockEnabled, false);
    notifyListeners();
  }

  String maskAmount(String value) => _hideBalances ? '••••' : value;
}
