import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/sync_model.dart';
import '../models/transaction.dart' as model;
import '../utils/security_utils.dart';
import 'database_service.dart';
import 'secure_storage_service.dart';

/// Service responsible for one-way sync (Local -> Supabase)
class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  SupabaseClient? _supabase;
  final DatabaseService _dbService = DatabaseService();

  bool get isInitialized => _supabase != null;

  /// Initialize Supabase with user-provided credentials
  Future<void> initialize(String url, String anonKey) async {
    // Validate credentials before initializing
    final urlValidation = SecurityUtils.validateSupabaseUrl(url);
    if (!urlValidation.isValid) {
      throw SecurityException(urlValidation.errorMessage!);
    }

    // Validate key format (basic check for JWT-like structure)
    if (anonKey.length < 20 || !anonKey.contains('.')) {
      throw SecurityException('Invalid API key format');
    }

    // Sanitize and validate
    final sanitizedUrl = urlValidation.value;
    
    await Supabase.initialize(
      url: sanitizedUrl,
      anonKey: anonKey.trim(),
    );
    _supabase = Supabase.instance.client;

    // Store credentials securely
    await SecureStorageService.storeSupabaseCredentials(sanitizedUrl, anonKey.trim());
  }

  /// Dispose Supabase client
  Future<void> dispose() async {
    _supabase = null;
    await Supabase.instance.dispose();
  }

  /// Perform one-way sync: upload all pending local changes to Supabase
  Future<SyncResult> performSync() async {
    if (_supabase == null) {
      return SyncResult.error('Supabase not initialized');
    }

    final results = <String, int>{};
    final errors = <String>[];

    try {
      // Sync in order of dependencies
      // 1. Categories (no dependencies)
      final categoryResult = await _syncCategories();
      results['categories'] = categoryResult.syncedCount;
      if (categoryResult.error != null) errors.add(categoryResult.error!);

      // 2. Accounts (no dependencies)
      final accountResult = await _syncAccounts();
      results['accounts'] = accountResult.syncedCount;
      if (accountResult.error != null) errors.add(accountResult.error!);

      // 3. Transactions (depends on categories and accounts)
      final transactionResult = await _syncTransactions();
      results['transactions'] = transactionResult.syncedCount;
      if (transactionResult.error != null) errors.add(transactionResult.error!);

      // 4. Loans (no dependencies)
      final loanResult = await _syncLoans();
      results['loans'] = loanResult.syncedCount;
      if (loanResult.error != null) errors.add(loanResult.error!);

      // 5. Recurring Transactions (depends on categories)
      final recurringResult = await _syncRecurringTransactions();
      results['recurring_transactions'] = recurringResult.syncedCount;
      if (recurringResult.error != null) errors.add(recurringResult.error!);

      // Update last sync time
      await _dbService.updateLastSyncTime();

      final totalSynced = results.values.fold(0, (sum, count) => sum + count);

      return SyncResult.success(
        syncedCount: totalSynced,
        details: results,
        errors: errors.isEmpty ? null : errors,
      );
    } catch (e) {
      return SyncResult.error('Sync failed: $e');
    }
  }

  Future<TableSyncResult> _syncCategories() async {
    return _syncTable<Category>(
      tableName: 'categories',
      fetchLocal: () => _dbService.getCategoriesForSync(),
      toSyncMap: (category) => category.toSyncMap(),
      markAsSynced: (localId, syncId) => 
          _dbService.markAsSynced('categories', localId, syncId),
      markAsFailed: (localId) => 
          _dbService.markAsFailed('categories', localId),
    );
  }

  Future<TableSyncResult> _syncAccounts() async {
    return _syncTable<Account>(
      tableName: 'accounts',
      fetchLocal: () => _dbService.getAccountsForSync(),
      toSyncMap: (account) => account.toSyncMap(),
      markAsSynced: (localId, syncId) => 
          _dbService.markAsSynced('accounts', localId, syncId),
      markAsFailed: (localId) => 
          _dbService.markAsFailed('accounts', localId),
    );
  }

  Future<TableSyncResult> _syncTransactions() async {
    return _syncTable<model.Transaction>(
      tableName: 'transactions',
      fetchLocal: () => _dbService.getTransactionsForSync(),
      toSyncMap: (transaction) => transaction.toSyncMap(),
      markAsSynced: (localId, syncId) => 
          _dbService.markAsSynced('transactions', localId, syncId),
      markAsFailed: (localId) => 
          _dbService.markAsFailed('transactions', localId),
    );
  }

  Future<TableSyncResult> _syncLoans() async {
    return _syncTable<Loan>(
      tableName: 'loans',
      fetchLocal: () => _dbService.getLoansForSync(),
      toSyncMap: (loan) => loan.toSyncMap(),
      markAsSynced: (localId, syncId) => 
          _dbService.markAsSynced('loans', localId, syncId),
      markAsFailed: (localId) => 
          _dbService.markAsFailed('loans', localId),
    );
  }

  Future<TableSyncResult> _syncRecurringTransactions() async {
    return _syncTable<RecurringTransaction>(
      tableName: 'recurring_transactions',
      fetchLocal: () => _dbService.getRecurringTransactionsForSync(),
      toSyncMap: (rt) => rt.toSyncMap(),
      markAsSynced: (localId, syncId) => 
          _dbService.markAsSynced('recurring_transactions', localId, syncId),
      markAsFailed: (localId) => 
          _dbService.markAsFailed('recurring_transactions', localId),
    );
  }

  Future<TableSyncResult> _syncTable<T extends SyncableModel>({
    required String tableName,
    required Future<List<T>> Function() fetchLocal,
    required Map<String, dynamic> Function(T) toSyncMap,
    required Future<void> Function(int localId, String syncId) markAsSynced,
    required Future<void> Function(int localId) markAsFailed,
  }) async {
    if (_supabase == null) {
      return TableSyncResult.error('Supabase not initialized');
    }

    try {
      final items = await fetchLocal();
      int syncedCount = 0;

      for (final item in items) {
        try {
          final map = toSyncMap(item);
          
          // Use upsert to handle both inserts and updates
          await _supabase!.from(tableName).upsert(
            map,
            onConflict: 'id',
          );

          // Mark as synced locally
          final localId = (item as dynamic).id as int?;
          if (localId != null) {
            await markAsSynced(localId, map['id'] as String);
          }

          syncedCount++;
        } catch (e) {
          debugPrint('Failed to sync item in $tableName: $e');
          final localId = (item as dynamic).id as int?;
          if (localId != null) {
            await markAsFailed(localId);
          }
        }
      }

      return TableSyncResult.success(syncedCount);
    } catch (e) {
      return TableSyncResult.error('Failed to sync $tableName: $e');
    }
  }

  /// Get count of pending sync items
  Future<int> getPendingCount() async {
    final categories = await _dbService.getCategoriesForSync();
    final accounts = await _dbService.getAccountsForSync();
    final transactions = await _dbService.getTransactionsForSync();
    final loans = await _dbService.getLoansForSync();
    final recurring = await _dbService.getRecurringTransactionsForSync();

    return categories.length + 
           accounts.length + 
           transactions.length + 
           loans.length + 
           recurring.length;
  }
}

/// Result of a sync operation
class SyncResult {
  final bool success;
  final int syncedCount;
  final Map<String, int>? details;
  final List<String>? errors;
  final String? errorMessage;

  SyncResult.success({
    required this.syncedCount,
    this.details,
    this.errors,
  }) : success = true, errorMessage = null;

  SyncResult.error(this.errorMessage)
      : success = false,
        syncedCount = 0,
        details = null,
        errors = null;

  bool get hasErrors => errors != null && errors!.isNotEmpty;
}

/// Result of syncing a single table
class TableSyncResult {
  final bool success;
  final int syncedCount;
  final String? error;

  TableSyncResult.success(this.syncedCount)
      : success = true,
        error = null;

  TableSyncResult.error(this.error)
      : success = false,
        syncedCount = 0;
}
