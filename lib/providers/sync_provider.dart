import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../services/database_service.dart';

/// Provider for sync state and operations
class SyncProvider extends ChangeNotifier {
  final SyncService _syncService = SyncService();
  final DatabaseService _dbService = DatabaseService();

  bool _isSyncing = false;
  bool _isConfigured = false;
  int _pendingCount = 0;
  DateTime? _lastSyncAt;
  String? _supabaseUrl;
  String? _lastError;
  SyncResult? _lastResult;

  // Getters
  bool get isSyncing => _isSyncing;
  bool get isConfigured => _isConfigured;
  int get pendingCount => _pendingCount;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get supabaseUrl => _supabaseUrl;
  String? get lastError => _lastError;
  SyncResult? get lastResult => _lastResult;

  /// Initialize and load configuration
  Future<void> initialize() async {
    await _loadConfiguration();
    await _updatePendingCount();
  }

  /// Load saved credentials and sync status
  Future<void> _loadConfiguration() async {
    try {
      final metadata = await _dbService.getSyncMetadata();
      if (metadata != null) {
        _supabaseUrl = metadata['supabaseUrl'] as String?;
        final supabaseKey = metadata['supabaseKey'] as String?;
        
        if (_supabaseUrl != null && supabaseKey != null && _supabaseUrl!.isNotEmpty) {
          await _syncService.initialize(_supabaseUrl!, supabaseKey);
          _isConfigured = _syncService.isInitialized;
        }

        final lastSync = metadata['lastSyncAt'] as String?;
        if (lastSync != null) {
          _lastSyncAt = DateTime.parse(lastSync);
        }
      }
    } catch (e) {
      debugPrint('Error loading sync configuration: $e');
      _isConfigured = false;
    }
    notifyListeners();
  }

  /// Configure Supabase credentials
  Future<bool> configureSupabase(String url, String anonKey) async {
    try {
      await _syncService.initialize(url, anonKey);
      
      if (_syncService.isInitialized) {
        _isConfigured = true;
        _supabaseUrl = url;
        _lastError = null;
        
        // Save credentials to database
        await _dbService.saveSyncCredentials(url, anonKey);
        
        notifyListeners();
        return true;
      }
    } catch (e) {
      _lastError = 'Failed to initialize: $e';
      _isConfigured = false;
    }
    
    notifyListeners();
    return false;
  }

  /// Clear saved credentials
  Future<void> clearConfiguration() async {
    try {
      await _syncService.dispose();
    } catch (e) {
      // Ignore dispose errors
    }
    
    await _dbService.clearSyncCredentials();
    _isConfigured = false;
    _supabaseUrl = null;
    _lastSyncAt = null;
    _lastError = null;
    _lastResult = null;
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

    if (!_isConfigured) {
      return SyncResult.error('Supabase not configured');
    }

    _isSyncing = true;
    _lastError = null;
    notifyListeners();

    try {
      final result = await _syncService.performSync();
      
      _lastResult = result;
      
      if (result.success) {
        _lastSyncAt = DateTime.now();
        _lastError = null;
      } else {
        _lastError = result.errorMessage;
      }

      await _updatePendingCount();
      
      // Refresh lastSyncAt from database
      final metadata = await _dbService.getSyncMetadata();
      if (metadata != null && metadata['lastSyncAt'] != null) {
        _lastSyncAt = DateTime.parse(metadata['lastSyncAt'] as String);
      }

      return result;
    } catch (e) {
      _lastError = 'Sync failed: $e';
      _lastResult = SyncResult.error(_lastError);
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

  /// Check if there are any sync conflicts
  bool get hasErrors => _lastResult?.hasErrors == true || _lastError != null;
}
