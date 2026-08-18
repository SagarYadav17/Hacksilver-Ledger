import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../models/account.dart';
import '../models/recurring_transaction.dart';
import '../models/loan.dart';
import '../models/sync_model.dart';
import '../constants/db_constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  String get _now => DateTime.now().toUtc().toIso8601String();

  void _prepareInsert(Map<String, dynamic> map) {
    map.remove(DbConstants.columnId);
    map[DbConstants.columnSyncId] ??= generateSyncId();
    map[DbConstants.columnUpdatedAt] = _now;
    map[DbConstants.columnSyncStatus] = 'pending';
  }

  void _prepareUpdate(Map<String, dynamic> map) {
    map.remove(DbConstants.columnId);
    if (map[DbConstants.columnSyncId] == null) {
      map.remove(DbConstants.columnSyncId);
    }
    map[DbConstants.columnUpdatedAt] = _now;
    map[DbConstants.columnSyncStatus] = 'pending';
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), DbConstants.databaseName);
    return await openDatabase(
      path,
      version: DbConstants.databaseVersion,
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCategoriesTable(db);
    await _createAccountsTable(db);
    await _createTransactionsTable(db);
    await _createRecurringTransactionsTable(db);
    await _createLoansTable(db);
    await _createSyncMetadataTable(db);
    await _createSyncHistoryTable(db);
  }

  Future<void> _createCategoriesTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableCategories}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnName} TEXT,
        ${DbConstants.columnCategoryIconCode} INTEGER,
        ${DbConstants.columnCategoryFontFamily} TEXT,
        ${DbConstants.columnCategoryFontPackage} TEXT,
        ${DbConstants.columnCategoryColorValue} INTEGER,
        ${DbConstants.columnCategoryType} INTEGER,
        ${DbConstants.columnCategoryIsCustom} INTEGER,
        ${DbConstants.columnCategorySortOrder} INTEGER DEFAULT 0,
        ${DbConstants.columnCategoryIsArchived} INTEGER DEFAULT 0,
        ${DbConstants.columnSyncId} TEXT NOT NULL UNIQUE,
        ${DbConstants.columnUpdatedAt} TEXT NOT NULL,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _createAccountsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableAccounts}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnName} TEXT,
        type INTEGER,
        ${DbConstants.columnAccountBalance} REAL,
        ${DbConstants.columnSyncId} TEXT NOT NULL UNIQUE,
        ${DbConstants.columnUpdatedAt} TEXT NOT NULL,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _createTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableTransactions}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnTransactionTitle} TEXT,
        ${DbConstants.columnTransactionAmount} REAL,
        ${DbConstants.columnDate} TEXT,
        ${DbConstants.columnType} INTEGER,
        ${DbConstants.columnTransactionCategoryId} INTEGER,
        ${DbConstants.columnTransactionAccountId} INTEGER,
        ${DbConstants.columnTransactionNotes} TEXT,
        ${DbConstants.columnTransactionOriginalAmount} REAL,
        ${DbConstants.columnTransactionOriginalCurrency} TEXT,
        ${DbConstants.columnTransactionLoanId} INTEGER,
        ${DbConstants.columnTransactionTransferAccountId} INTEGER,
        ${DbConstants.columnTransactionRecurringId} INTEGER,
        ${DbConstants.columnSyncId} TEXT NOT NULL UNIQUE,
        ${DbConstants.columnUpdatedAt} TEXT NOT NULL,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(${DbConstants.columnTransactionCategoryId}) REFERENCES ${DbConstants.tableCategories}(${DbConstants.columnId}),
        FOREIGN KEY(${DbConstants.columnTransactionAccountId}) REFERENCES ${DbConstants.tableAccounts}(${DbConstants.columnId})
      )
    ''');
  }

  Future<void> _createRecurringTransactionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableRecurringTransactions}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnRecurringTransactionTitle} TEXT,
        ${DbConstants.columnRecurringTransactionAmount} REAL,
        ${DbConstants.columnType} INTEGER,
        ${DbConstants.columnRecurringTransactionCategoryId} INTEGER,
        ${DbConstants.columnRecurringTransactionAccountId} INTEGER,
        ${DbConstants.columnRecurringTransactionFrequency} INTEGER,
        startDate TEXT,
        nextDueDate TEXT,
        ${DbConstants.columnRecurringTransactionIsActive} INTEGER,
        ${DbConstants.columnRecurringTransactionNotes} TEXT,
        ${DbConstants.columnSyncId} TEXT NOT NULL UNIQUE,
        ${DbConstants.columnUpdatedAt} TEXT NOT NULL,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY(${DbConstants.columnRecurringTransactionCategoryId}) REFERENCES ${DbConstants.tableCategories}(${DbConstants.columnId})
      )
    ''');
  }

  Future<void> _createLoansTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableLoans}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        ${DbConstants.columnLoanInterestRate} REAL,
        tenureMonths INTEGER,
        ${DbConstants.columnType} INTEGER,
        ${DbConstants.columnLoanStartDate} TEXT,
        emiAmount REAL,
        ${DbConstants.columnLoanAmountPaid} REAL,
        isClosed INTEGER,
        notes TEXT,
        ${DbConstants.columnSyncId} TEXT NOT NULL UNIQUE,
        ${DbConstants.columnUpdatedAt} TEXT NOT NULL,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _createSyncMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableSyncMetadata}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY,
        ${DbConstants.columnPocketBaseUrl} TEXT,
        ${DbConstants.columnLastSyncAt} TEXT,
        ${DbConstants.columnLastPullAt} TEXT,
        ${DbConstants.columnLastSyncError} TEXT
      )
    ''');

    // Insert default row
    await db.execute('''
      INSERT INTO ${DbConstants.tableSyncMetadata} (${DbConstants.columnId}, ${DbConstants.columnPocketBaseUrl}, ${DbConstants.columnLastSyncAt}, ${DbConstants.columnLastPullAt}, ${DbConstants.columnLastSyncError})
      VALUES (1, NULL, NULL, NULL, NULL)
    ''');
  }

  Future<void> _createSyncHistoryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${DbConstants.tableSyncHistory}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnSyncHistoryStatus} TEXT NOT NULL,
        ${DbConstants.columnSyncHistorySyncedCount} INTEGER NOT NULL,
        ${DbConstants.columnSyncHistoryMessage} TEXT,
        ${DbConstants.columnSyncHistoryCreatedAt} TEXT NOT NULL
      )
    ''');
  }

  // Category CRUD with sync support
  Future<int> insertCategory(Category category) async {
    final db = await database;
    final map = category.toMap();
    _prepareInsert(map);
    return await db.insert(DbConstants.tableCategories, map);
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    final map = category.toMap();
    _prepareUpdate(map);
    return await db.update(
      DbConstants.tableCategories,
      map,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> reassignCategory(int fromCategoryId, int toCategoryId) async {
    final db = await database;
    await db.update(
      DbConstants.tableTransactions,
      {
        DbConstants.columnTransactionCategoryId: toCategoryId,
        DbConstants.columnUpdatedAt: _now,
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnTransactionCategoryId} = ?',
      whereArgs: [fromCategoryId],
    );
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableCategories,
      where: '${DbConstants.columnDeletedAt} IS NULL',
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<List<Category>> getCategoriesForSync() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableCategories,
      where: '${DbConstants.columnSyncStatus} != ?',
      whereArgs: ['synced'],
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.update(
      DbConstants.tableCategories,
      {
        DbConstants.columnDeletedAt: _now,
        DbConstants.columnUpdatedAt: _now,
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  Future<int> permanentlyDeleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableCategories,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Account CRUD with sync support
  Future<int> insertAccount(Account account) async {
    final db = await database;
    final map = account.toMap();
    _prepareInsert(map);
    return await db.insert(DbConstants.tableAccounts, map);
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableAccounts,
      where: '${DbConstants.columnDeletedAt} IS NULL',
    );
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<List<Account>> getAccountsForSync() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableAccounts,
      where: '${DbConstants.columnSyncStatus} != ?',
      whereArgs: ['synced'],
    );
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    final map = account.toMap();
    _prepareUpdate(map);
    return await db.update(
      DbConstants.tableAccounts,
      map,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.update(
      DbConstants.tableAccounts,
      {
        DbConstants.columnDeletedAt: _now,
        DbConstants.columnUpdatedAt: _now,
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Transaction CRUD with sync support
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    final map = transaction.toMap();
    _prepareInsert(map);
    return await db.insert(DbConstants.tableTransactions, map);
  }

  Future<List<model.Transaction>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTransactions,
      where: '${DbConstants.columnDeletedAt} IS NULL',
      orderBy: '${DbConstants.columnDate} DESC',
    );
    return List.generate(
      maps.length,
      (i) => model.Transaction.fromMap(maps[i]),
    );
  }

  Future<List<model.Transaction>> getTransactionsForSync() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTransactions,
      where: '${DbConstants.columnSyncStatus} != ?',
      whereArgs: ['synced'],
      orderBy: '${DbConstants.columnDate} DESC',
    );
    return List.generate(
      maps.length,
      (i) => model.Transaction.fromMap(maps[i]),
    );
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    final map = transaction.toMap();
    _prepareUpdate(map);
    return await db.update(
      DbConstants.tableTransactions,
      map,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.update(
      DbConstants.tableTransactions,
      {
        DbConstants.columnDeletedAt: _now,
        DbConstants.columnUpdatedAt: _now,
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Recurring Transaction CRUD with sync support
  Future<int> insertRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    final map = transaction.toMap();
    _prepareInsert(map);
    return await db.insert(DbConstants.tableRecurringTransactions, map);
  }

  Future<int> updateRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    final map = transaction.toMap();
    _prepareUpdate(map);
    return await db.update(
      DbConstants.tableRecurringTransactions,
      map,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableRecurringTransactions,
      where: '${DbConstants.columnDeletedAt} IS NULL',
    );
    return List.generate(
      maps.length,
      (i) => RecurringTransaction.fromMap(maps[i]),
    );
  }

  Future<List<RecurringTransaction>> getRecurringTransactionsForSync() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableRecurringTransactions,
      where: '${DbConstants.columnSyncStatus} != ?',
      whereArgs: ['synced'],
    );
    return List.generate(
      maps.length,
      (i) => RecurringTransaction.fromMap(maps[i]),
    );
  }

  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return await db.update(
      DbConstants.tableRecurringTransactions,
      {
        DbConstants.columnDeletedAt: _now,
        DbConstants.columnUpdatedAt: _now,
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Loan CRUD with sync support
  Future<int> insertLoan(Loan loan) async {
    final db = await database;
    final map = loan.toMap();
    _prepareInsert(map);
    return await db.insert(DbConstants.tableLoans, map);
  }

  Future<List<Loan>> getLoans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableLoans,
      where: '${DbConstants.columnDeletedAt} IS NULL',
    );
    return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
  }

  Future<List<Loan>> getLoansForSync() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableLoans,
      where: '${DbConstants.columnSyncStatus} != ?',
      whereArgs: ['synced'],
    );
    return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
  }

  Future<int> updateLoan(Loan loan) async {
    final db = await database;
    final map = loan.toMap();
    _prepareUpdate(map);
    return await db.update(
      DbConstants.tableLoans,
      map,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [loan.id],
    );
  }

  Future<int> deleteLoan(int id) async {
    final db = await database;
    return await db.update(
      DbConstants.tableLoans,
      {
        DbConstants.columnDeletedAt: _now,
        DbConstants.columnUpdatedAt: _now,
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Sync Status Updates
  Future<void> markAsSynced(
    String tableName,
    int localId,
    String syncId,
  ) async {
    final db = await database;
    await db.update(
      tableName,
      {
        DbConstants.columnSyncId: syncId,
        DbConstants.columnSyncStatus: 'synced',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markAsFailed(String tableName, int localId) async {
    final db = await database;
    await db.update(
      tableName,
      {DbConstants.columnSyncStatus: 'failed'},
      where: '${DbConstants.columnId} = ?',
      whereArgs: [localId],
    );
  }

  Future<String> getSyncId(String tableName, int localId) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      columns: [DbConstants.columnSyncId],
      where: '${DbConstants.columnId} = ?',
      whereArgs: [localId],
      limit: 1,
    );
    final syncId = rows.isEmpty
        ? null
        : rows.first[DbConstants.columnSyncId] as String?;
    if (syncId == null) {
      throw StateError('Missing sync ID for $tableName/$localId');
    }
    return syncId;
  }

  Future<int?> getLocalId(String tableName, String syncId) async {
    final db = await database;
    final rows = await db.query(
      tableName,
      columns: [DbConstants.columnId],
      where: '${DbConstants.columnSyncId} = ?',
      whereArgs: [syncId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first[DbConstants.columnId] as int;
  }

  /// Applies a remote record unless a newer local change still needs upload.
  Future<RemoteApplyResult> applyRemoteRecord(
    String tableName,
    Map<String, dynamic> values,
  ) async {
    final db = await database;
    final syncId = values[DbConstants.columnSyncId] as String;
    final remoteUpdatedAt = values[DbConstants.columnUpdatedAt] as String;
    final local = await db.query(
      tableName,
      where: '${DbConstants.columnSyncId} = ?',
      whereArgs: [syncId],
      limit: 1,
    );

    if (local.isEmpty) {
      await db.insert(tableName, values);
      return RemoteApplyResult.applied;
    }

    final current = local.first;
    final localUpdatedAt = DateTime.parse(
      current[DbConstants.columnUpdatedAt] as String,
    ).toUtc();
    if (!shouldApplyRemote(localUpdatedAt, DateTime.parse(remoteUpdatedAt))) {
      await db.update(
        tableName,
        {DbConstants.columnSyncStatus: 'conflict'},
        where: '${DbConstants.columnId} = ?',
        whereArgs: [current[DbConstants.columnId]],
      );
      return RemoteApplyResult.localNewer;
    }

    await db.update(
      tableName,
      values,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [current[DbConstants.columnId]],
    );
    return RemoteApplyResult.applied;
  }

  Future<void> updateLastPullTime() async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {DbConstants.columnLastPullAt: _now},
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  // Sync Metadata
  Future<Map<String, dynamic>?> getSyncMetadata() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableSyncMetadata,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

  Future<void> savePocketBaseUrl(String url) async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {DbConstants.columnPocketBaseUrl: url},
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateLastSyncTime() async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {
        DbConstants.columnLastSyncAt: _now,
        DbConstants.columnLastSyncError: null,
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  Future<void> recordSyncError(String message) async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {DbConstants.columnLastSyncError: message},
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  Future<void> clearSyncCredentials() async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {
        DbConstants.columnPocketBaseUrl: null,
        DbConstants.columnLastSyncAt: null,
        DbConstants.columnLastPullAt: null,
        DbConstants.columnLastSyncError: null,
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  Future<void> insertSyncHistory({
    required bool success,
    required int syncedCount,
    String? message,
  }) async {
    final db = await database;
    await db.insert(DbConstants.tableSyncHistory, {
      DbConstants.columnSyncHistoryStatus: success ? 'success' : 'failed',
      DbConstants.columnSyncHistorySyncedCount: syncedCount,
      DbConstants.columnSyncHistoryMessage: message,
      DbConstants.columnSyncHistoryCreatedAt: _now,
    });
  }

  Future<List<Map<String, dynamic>>> getSyncHistory({int limit = 5}) async {
    final db = await database;
    return db.query(
      DbConstants.tableSyncHistory,
      orderBy: '${DbConstants.columnSyncHistoryCreatedAt} DESC',
      limit: limit,
    );
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}

enum RemoteApplyResult { applied, localNewer }

bool shouldApplyRemote(DateTime localUpdatedAt, DateTime remoteUpdatedAt) =>
    !localUpdatedAt.toUtc().isAfter(remoteUpdatedAt.toUtc());
