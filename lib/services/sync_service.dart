import 'package:flutter/material.dart';
import 'package:pocketbase/pocketbase.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/loan.dart';
import '../models/recurring_transaction.dart';
import '../models/sync_model.dart';
import '../models/transaction.dart' as model;
import '../constants/db_constants.dart';
import 'database_service.dart';

/// Service responsible for local-to-PocketBase sync.
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

  /// Push local changes, then pull and atomically apply remote records.
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

      // 3. Loans (no dependencies)
      final loanResult = await _syncLoans();
      results['loans'] = loanResult.syncedCount;
      if (loanResult.error != null) errors.add(loanResult.error!);

      // 4. Recurring Transactions (depends on categories and accounts)
      final recurringResult = await _syncRecurringTransactions();
      results['recurring_transactions'] = recurringResult.syncedCount;
      if (recurringResult.error != null) errors.add(recurringResult.error!);

      // 5. Transactions (depends on categories, accounts, loans, and rules)
      final transactionResult = await _syncTransactions();
      results['transactions'] = transactionResult.syncedCount;
      if (transactionResult.error != null) errors.add(transactionResult.error!);

      final pullResult = await _pullRemoteChanges();
      if (pullResult.error != null) errors.add(pullResult.error!);

      if (errors.isEmpty) {
        await _dbService.updateLastSyncTime();
        await _dbService.updateLastPullTime();
      } else {
        await _dbService.recordSyncError(errors.join('; '));
      }

      final totalSynced = results.values.fold(0, (sum, count) => sum + count);

      return SyncResult.success(
        syncedCount: totalSynced,
        pulledCount: pullResult.appliedCount,
        conflictCount: pullResult.conflictCount,
        details: results,
        errors: errors.isEmpty ? null : errors,
      );
    } catch (e) {
      return SyncResult.error('Sync failed: $e');
    }
  }

  Future<PullResult> _pullRemoteChanges() async {
    final pb = _pb;
    if (pb == null || !isInitialized) return PullResult.error('Not logged in');

    try {
      var appliedCount = 0;
      var conflictCount = 0;
      for (final tableName in const [
        'categories',
        'accounts',
        'loans',
        'recurring_transactions',
        'transactions',
      ]) {
        final records = await pb
            .collection(tableName)
            .getFullList(batch: 200, sort: 'updated_at');
        for (final record in records) {
          final result = await _applyRemoteRecord(tableName, record.data);
          if (result == RemoteApplyResult.applied) {
            appliedCount++;
          } else {
            conflictCount++;
          }
        }
      }
      return PullResult.success(appliedCount, conflictCount);
    } catch (e) {
      return PullResult.error('Failed to pull changes: $e');
    }
  }

  Future<RemoteApplyResult> _applyRemoteRecord(
    String tableName,
    Map<String, dynamic> remote,
  ) async {
    final syncId = remote['local_sync_id'] as String?;
    final updatedAt = remote['updated_at'] as String?;
    if (syncId == null || updatedAt == null) {
      throw FormatException(
        'Remote $tableName record is missing sync metadata',
      );
    }

    final values = <String, dynamic>{
      DbConstants.columnSyncId: syncId,
      DbConstants.columnUpdatedAt: updatedAt,
      DbConstants.columnDeletedAt: remote['deleted_at'],
      DbConstants.columnSyncStatus: 'synced',
      ...await _localValuesFor(tableName, remote),
    };
    return _dbService.applyRemoteRecord(tableName, values);
  }

  Future<Map<String, dynamic>> _localValuesFor(
    String tableName,
    Map<String, dynamic> remote,
  ) async {
    Future<int?> localId(
      String field,
      String target, {
      bool required = false,
    }) async {
      final syncId = remote[field] as String?;
      if (syncId == null) {
        if (required) {
          throw FormatException('Remote $tableName record is missing $field');
        }
        return null;
      }
      final id = await _dbService.getLocalId(target, syncId);
      if (id == null && required) {
        throw FormatException(
          'Unknown $field $syncId in remote $tableName record',
        );
      }
      return id;
    }

    switch (tableName) {
      case 'categories':
        return {
          'name': remote['name'],
          'iconCode': _int(remote['icon_code']),
          'fontFamily': remote['font_family'],
          'fontPackage': remote['font_package'],
          'colorValue': _int(remote['color_value']),
          'type': _index(remote['type'], const [
            'income',
            'expense',
            'transfer',
          ]),
          'isCustom': _bool(remote['is_custom']) ? 1 : 0,
          'sortOrder': _int(remote['sort_order'], defaultValue: 0),
          'isArchived': _bool(remote['is_archived']) ? 1 : 0,
        };
      case 'accounts':
        return {
          'name': remote['name'],
          'type': _index(remote['type'], const [
            'cash',
            'bank',
            'creditCard',
            'other',
          ]),
          'balance': _double(remote['balance']),
        };
      case 'loans':
        return {
          'title': remote['title'],
          'amount': _double(remote['amount']),
          'interestRate': _double(remote['interest_rate']),
          'tenureMonths': _int(remote['tenure_months']),
          'type': _index(remote['type'], const ['given', 'taken']),
          'startDate': remote['start_date'],
          'emiAmount': _double(remote['emi_amount']),
          'amountPaid': _double(remote['amount_paid']),
          'isClosed': _bool(remote['is_closed']) ? 1 : 0,
          'notes': remote['notes'],
        };
      case 'recurring_transactions':
        return {
          'title': remote['title'],
          'amount': _double(remote['amount']),
          'type': _index(remote['type'], const [
            'income',
            'expense',
            'transfer',
          ]),
          'categoryId': await localId(
            'category_sync_id',
            'categories',
            required: true,
          ),
          'accountId': await localId('account_sync_id', 'accounts'),
          'frequency': _index(remote['frequency'], const [
            'daily',
            'monthly',
            'quarterly',
            'yearly',
          ]),
          'startDate': remote['start_date'],
          'nextDueDate': remote['next_due_date'],
          'isActive': _bool(remote['is_active']) ? 1 : 0,
          'notes': remote['notes'],
        };
      case 'transactions':
        return {
          'title': remote['title'],
          'amount': _double(remote['amount']),
          'date': remote['date'],
          'type': _index(remote['type'], const [
            'income',
            'expense',
            'transfer',
          ]),
          'categoryId': await localId(
            'category_sync_id',
            'categories',
            required: true,
          ),
          'accountId': await localId('account_sync_id', 'accounts'),
          'transferAccountId': await localId(
            'transfer_account_sync_id',
            'accounts',
          ),
          'notes': remote['notes'],
          'originalAmount': remote['original_amount'] == null
              ? null
              : _double(remote['original_amount']),
          'originalCurrency': remote['original_currency'],
          'loanId': await localId('loan_sync_id', 'loans'),
          'recurringId': await localId(
            'recurring_sync_id',
            'recurring_transactions',
          ),
        };
    }
    throw ArgumentError.value(tableName, 'tableName');
  }

  int _int(dynamic value, {int? defaultValue}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.parse(value);
    if (defaultValue != null) return defaultValue;
    throw FormatException('Expected integer, got $value');
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.parse(value);
    throw FormatException('Expected number, got $value');
  }

  bool _bool(dynamic value) => value == true || value == 1 || value == 'true';

  int _index(dynamic value, List<String> values) {
    final index = values.indexOf(value);
    if (index < 0) throw FormatException('Unknown enum value: $value');
    return index;
  }

  Future<TableSyncResult> _syncCategories() async {
    return _syncTable<Category>(
      tableName: 'categories',
      fetchLocal: () => _dbService.getCategoriesForSync(),
      toSyncMap: (category) async => category.toSyncMap(),
      markAsSynced: (localId, syncId) =>
          _dbService.markAsSynced('categories', localId, syncId),
      markAsFailed: (localId) => _dbService.markAsFailed('categories', localId),
    );
  }

  Future<TableSyncResult> _syncAccounts() async {
    return _syncTable<Account>(
      tableName: 'accounts',
      fetchLocal: () => _dbService.getAccountsForSync(),
      toSyncMap: (account) async => account.toSyncMap(),
      markAsSynced: (localId, syncId) =>
          _dbService.markAsSynced('accounts', localId, syncId),
      markAsFailed: (localId) => _dbService.markAsFailed('accounts', localId),
    );
  }

  Future<TableSyncResult> _syncTransactions() async {
    return _syncTable<model.Transaction>(
      tableName: 'transactions',
      fetchLocal: () => _dbService.getTransactionsForSync(),
      toSyncMap: (transaction) async => transaction.toSyncMap(),
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
      toSyncMap: (loan) async => loan.toSyncMap(),
      markAsSynced: (localId, syncId) =>
          _dbService.markAsSynced('loans', localId, syncId),
      markAsFailed: (localId) => _dbService.markAsFailed('loans', localId),
    );
  }

  Future<TableSyncResult> _syncRecurringTransactions() async {
    return _syncTable<RecurringTransaction>(
      tableName: 'recurring_transactions',
      fetchLocal: () => _dbService.getRecurringTransactionsForSync(),
      toSyncMap: (rt) async => rt.toSyncMap(),
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
    required Future<Map<String, dynamic>> Function(T) toSyncMap,
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
      int failedCount = 0;
      final collection = pb.collection(tableName);

      for (final item in items) {
        try {
          final syncMap = await toSyncMap(item);
          final localSyncId = syncMap.remove('id') as String;
          final body = {
            ...await _replaceLocalReferences(tableName, syncMap),
            'local_sync_id': localSyncId,
            'user': pb.authStore.record!.id,
          };

          try {
            final existing = await collection.getFirstListItem(
              "local_sync_id='$localSyncId'",
            );
            final remoteUpdatedAt = existing.data['updated_at'] as String?;
            final localUpdatedAt = body['updated_at'] as String;
            if (remoteUpdatedAt != null &&
                DateTime.parse(
                  remoteUpdatedAt,
                ).isAfter(DateTime.parse(localUpdatedAt))) {
              continue;
            }
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
          failedCount++;
          debugPrint('Failed to sync item in $tableName: $e');
          final localId = (item as dynamic).id as int?;
          if (localId != null) {
            await markAsFailed(localId);
          }
        }
      }

      return failedCount == 0
          ? TableSyncResult.success(syncedCount)
          : TableSyncResult.partial(syncedCount, failedCount);
    } catch (e) {
      return TableSyncResult.error('Failed to sync $tableName: $e');
    }
  }

  Future<Map<String, dynamic>> _replaceLocalReferences(
    String tableName,
    Map<String, dynamic> syncMap,
  ) async {
    final body = Map<String, dynamic>.from(syncMap)..remove('local_id');

    Future<void> replace(
      String localField,
      String syncField,
      String targetTable,
    ) async {
      final localId = body.remove(localField);
      if (localId != null) {
        body[syncField] = await _dbService.getSyncId(
          targetTable,
          localId as int,
        );
      }
    }

    if (tableName == 'recurring_transactions') {
      await replace('category_id', 'category_sync_id', 'categories');
      await replace('account_id', 'account_sync_id', 'accounts');
    }
    if (tableName == 'transactions') {
      await replace('category_id', 'category_sync_id', 'categories');
      await replace('account_id', 'account_sync_id', 'accounts');
      await replace(
        'transfer_account_id',
        'transfer_account_sync_id',
        'accounts',
      );
      await replace('loan_id', 'loan_sync_id', 'loans');
      await replace(
        'recurring_id',
        'recurring_sync_id',
        'recurring_transactions',
      );
    }
    return body;
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
  final int pulledCount;
  final int conflictCount;
  final Map<String, int>? details;
  final List<String>? errors;
  final String? errorMessage;

  SyncResult.success({
    required this.syncedCount,
    this.pulledCount = 0,
    this.conflictCount = 0,
    this.details,
    this.errors,
  }) : success = errors == null || errors.isEmpty,
       errorMessage = errors == null || errors.isEmpty
           ? null
           : errors.join('; ');

  SyncResult.error(this.errorMessage)
    : success = false,
      syncedCount = 0,
      pulledCount = 0,
      conflictCount = 0,
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

  TableSyncResult.partial(this.syncedCount, int failedCount)
    : success = false,
      error = '$failedCount item(s) failed to sync';

  TableSyncResult.error(this.error) : success = false, syncedCount = 0;
}

class PullResult {
  final int appliedCount;
  final int conflictCount;
  final String? error;

  PullResult.success(this.appliedCount, this.conflictCount) : error = null;

  PullResult.error(this.error) : appliedCount = 0, conflictCount = 0;
}
