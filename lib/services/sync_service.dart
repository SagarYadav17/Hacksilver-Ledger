import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/sync_model.dart';
import '../models/transaction.dart' as model;
import 'database_service.dart';

/// Service responsible for one-way sync (Local -> PocketBase).
/// Uses the PocketBase client owned by AuthProvider so requests carry the
/// logged-in user's identity; every synced row is stamped with `user` so
/// PocketBase's API rules can scope it to that account only.
class SyncService {
  final DatabaseService _dbService = DatabaseService();
  PocketBase? _pb;

  bool get isInitialized => _pb != null && _pb!.authStore.isValid;

  /// Bind (or rebind) the authenticated PocketBase client to use for sync.
  void bindClient(PocketBase? client) {
    _pb = client;
  }

  /// Perform one-way sync: upload all pending local changes to PocketBase
  Future<SyncResult> performSync() async {
    if (!isInitialized) {
      return SyncResult.error('Not logged in');
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
      markAsFailed: (localId) => _dbService.markAsFailed('categories', localId),
    );
  }

  Future<TableSyncResult> _syncAccounts() async {
    return _syncTable<Account>(
      tableName: 'accounts',
      fetchLocal: () => _dbService.getAccountsForSync(),
      toSyncMap: (account) => account.toSyncMap(),
      markAsSynced: (localId, syncId) =>
          _dbService.markAsSynced('accounts', localId, syncId),
      markAsFailed: (localId) => _dbService.markAsFailed('accounts', localId),
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
      markAsFailed: (localId) => _dbService.markAsFailed('loans', localId),
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

  /// Finds the remote record by `local_sync_id` and updates it, or creates
  /// a new one if it doesn't exist yet. PocketBase controls its own `id`
  /// format, so our locally-generated sync id is carried in a separate
  /// `local_sync_id` field instead of PocketBase's primary key.
  Future<TableSyncResult> _syncTable<T extends SyncableModel>({
    required String tableName,
    required Future<List<T>> Function() fetchLocal,
    required Map<String, dynamic> Function(T) toSyncMap,
    required Future<void> Function(int localId, String syncId) markAsSynced,
    required Future<void> Function(int localId) markAsFailed,
  }) async {
    final pb = _pb;
    if (pb == null || !isInitialized) {
      return TableSyncResult.error('Not logged in');
    }

    try {
      final items = await fetchLocal();
      int syncedCount = 0;
      final collection = pb.collection(tableName);

      for (final item in items) {
        try {
          final syncMap = toSyncMap(item);
          final localSyncId = syncMap.remove('id') as String;
          final body = {
            ...syncMap,
            'local_sync_id': localSyncId,
            'user': pb.authStore.record!.id,
          };

          try {
            final existing = await collection.getFirstListItem(
              "local_sync_id='$localSyncId'",
            );
            await collection.update(existing.id, body: body);
          } on ClientException catch (e) {
            if (e.statusCode != 404) rethrow;
            await collection.create(body: body);
          }

          final localId = (item as dynamic).id as int?;
          if (localId != null) {
            await markAsSynced(localId, localSyncId);
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

  SyncResult.success({required this.syncedCount, this.details, this.errors})
    : success = true,
      errorMessage = null;

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

  TableSyncResult.success(this.syncedCount) : success = true, error = null;

  TableSyncResult.error(this.error) : success = false, syncedCount = 0;
}
