import 'package:flutter/material.dart';
import 'auth_provider.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';

/// Provider for sync state and operations. Auth/connection lifecycle lives
/// in AuthProvider; this provider only cares about running syncs against
/// whichever authenticated client AuthProvider currently holds.
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final DatabaseService _dbService = DatabaseService();

  bool _isSyncing = false;
  bool _boundLoggedIn = false;
  int _pendingCount = 0;
  DateTime? _lastSyncAt;
  DateTime? _lastPullAt;
  String? _lastError;
  SyncResult? _lastResult;
  List<Map<String, dynamic>> _syncHistory = [];

  // Getters
  bool get isSyncing => _isSyncing;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncAt => _lastSyncAt;
  DateTime? get lastPullAt => _lastPullAt;
  String? get lastError => _lastError;
  SyncResult? get lastResult => _lastResult;
  List<Map<String, dynamic>> get syncHistory => _syncHistory;
  bool get hasErrors => _lastResult?.hasErrors == true || _lastError != null;

  /// Called by the ChangeNotifierProxyProvider whenever AuthProvider changes
  /// (login, logout, or session restore) so sync always targets the current
  /// authenticated client.
  void bindAuth(AuthProvider auth) {
    _syncService.bindClient(auth.client);

    final justLoggedIn = auth.isLoggedIn && !_boundLoggedIn;
    _boundLoggedIn = auth.isLoggedIn;

    if (justLoggedIn) {
      _loadLastSyncAt();
      _updatePendingCount();
      _loadSyncHistory();
    }
  }

  Future<void> _loadLastSyncAt() async {
    final metadata = await _dbService.getSyncMetadata();
    final lastSync = metadata?['lastSyncAt'] as String?;
    final lastPull = metadata?['lastPullAt'] as String?;
    _lastSyncAt = lastSync != null ? DateTime.parse(lastSync) : null;
    _lastPullAt = lastPull != null ? DateTime.parse(lastPull) : null;
    notifyListeners();
  }

  /// Update pending count
  Future<void> _updatePendingCount() async {
    try {
      _pendingCount = await _syncService.getPendingCount();
    } catch (e) {
      _pendingCount = 0;
    }
    notifyListeners();
  }

  /// Perform manual sync
  Future<SyncResult> syncNow() async {
    if (_isSyncing) {
      return SyncResult.error('Sync already in progress');
    }

    if (!_syncService.isInitialized) {
      return SyncResult.error('Not logged in');
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _syncService.performSync();

      _lastResult = result;

      if (result.success) {
        _lastError = null;
      } else {
        _lastError = result.errorMessage;
      }

      await _dbService.insertSyncHistory(
        success: result.success,
        syncedCount: result.syncedCount,
        message: result.success
            ? 'Uploaded ${result.syncedCount} item(s)'
            : result.errorMessage,
      );

      await _updatePendingCount();
      await _loadSyncHistory();
      await _loadLastSyncAt();

      return result;
    } catch (e) {
      _lastError = 'Sync failed: $e';
      _lastResult = SyncResult.error(_lastError);
      await _dbService.insertSyncHistory(
        success: false,
        syncedCount: 0,
        message: _lastError,
      );
      await _loadSyncHistory();
      return _lastResult!;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Refresh pending count
  Future<void> refreshPendingCount() async {
    await _updatePendingCount();
  }

  Future<void> _loadSyncHistory() async {
    try {
      _syncHistory = await _dbService.getSyncHistory();
    } catch (e) {
      _syncHistory = [];
    }
    notifyListeners();
  }
}
