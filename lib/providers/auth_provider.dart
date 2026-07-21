import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/security_utils.dart';

/// Owns the PocketBase client + auth session. Shared with SyncService so
/// sync requests carry the same authenticated identity as the login screen.
class AuthProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();

  PocketBase? _pb;
  String? _serverUrl;
  String? _lastError;
  bool _isLoading = true;
  bool _isBusy = false;

  PocketBase? get client => _pb;
  String? get serverUrl => _serverUrl;
  String? get lastError => _lastError;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  bool get isLoggedIn => _pb?.authStore.isValid ?? false;
  RecordModel? get currentUser => _pb?.authStore.record;
  String? get currentEmail => currentUser?.data['email'] as String?;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final metadata = await _dbService.getSyncMetadata();
      final savedUrl = metadata?['pocketbaseUrl'] as String?;
      if (savedUrl != null && savedUrl.isNotEmpty) {
        _connectClient(savedUrl);
        await _restoreSession();
      }
    } catch (e) {
      debugPrint('Error restoring PocketBase session: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _connectClient(String url) {
    _serverUrl = url;
    _pb = PocketBase(url);
  }

  Future<void> _restoreSession() async {
    final savedAuth = await SecureStorageService.getPocketBaseAuth();
    if (savedAuth == null || _pb == null) return;

    try {
      final decoded = jsonDecode(savedAuth) as Map<String, dynamic>;
      final token = decoded['token'] as String;
      final recordJson = decoded['record'] as Map<String, dynamic>?;
      _pb!.authStore.save(
        token,
        recordJson != null ? RecordModel.fromJson(recordJson) : null,
      );

      // Confirm the token is still valid against the server.
      await _pb!.collection('users').authRefresh();
      await _persistSession();
    } catch (e) {
      _pb!.authStore.clear();
      await SecureStorageService.clearPocketBaseAuth();
    }
  }

  Future<void> _persistSession() async {
    if (_pb == null || !_pb!.authStore.isValid) return;
    final json = jsonEncode({
      'token': _pb!.authStore.token,
      'record': _pb!.authStore.record?.toJson(),
    });
    await SecureStorageService.storePocketBaseAuth(json);
  }

  /// Connects to (or switches) the PocketBase server. Does not attempt login.
  Future<bool> connect(String url) async {
    final validation = SecurityUtils.validateServerUrl(url);
    if (!validation.isValid) {
      _lastError = validation.errorMessage;
      notifyListeners();
      return false;
    }

    _connectClient(validation.value);
    await _dbService.savePocketBaseUrl(validation.value);
    _lastError = null;
    notifyListeners();
    return true;
  }

  Future<bool> signUp(String email, String password) async {
    if (_pb == null) {
      _lastError = 'Connect to a server first';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _lastError = null;
    notifyListeners();

    try {
      await _pb!
          .collection('users')
          .create(
            body: {
              'email': email,
              'password': password,
              'passwordConfirm': password,
            },
          );
      return await logIn(email, password);
    } catch (e) {
      _lastError = _describeError(e);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> logIn(String email, String password) async {
    if (_pb == null) {
      _lastError = 'Connect to a server first';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    _lastError = null;
    notifyListeners();

    try {
      await _pb!.collection('users').authWithPassword(email, password);
      await _persistSession();
      return true;
    } catch (e) {
      _lastError = _describeError(e);
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> logOut() async {
    _pb?.authStore.clear();
    await SecureStorageService.clearPocketBaseAuth();
    notifyListeners();
  }

  String _describeError(Object e) {
    if (e is ClientException) {
      final message = e.response['message'] as String?;
      if (message != null && message.isNotEmpty) return message;
    }
    return 'Something went wrong. Please try again.';
  }
}
