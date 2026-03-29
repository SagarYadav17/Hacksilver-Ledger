import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../models/account.dart';
import '../models/recurring_transaction.dart';
import '../models/loan.dart';
import '../constants/db_constants.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

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
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCategoriesTable(db);
    await _createAccountsTable(db);
    await _createTransactionsTable(db);
    await _createRecurringTransactionsTable(db);
    await _createLoansTable(db);
    await _createSyncMetadataTable(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _addSyncColumns(db, DbConstants.tableCategories);
      await _addSyncColumns(db, DbConstants.tableAccounts);
      await _addSyncColumns(db, DbConstants.tableTransactions);
      await _addSyncColumns(db, DbConstants.tableRecurringTransactions);
      await _addSyncColumns(db, DbConstants.tableLoans);
      await _createSyncMetadataTable(db);
    }
  }

  Future<void> _addSyncColumns(Database db, String tableName) async {
    try {
      await db.execute('ALTER TABLE $tableName ADD COLUMN ${DbConstants.columnSyncId} TEXT');
      await db.execute('ALTER TABLE $tableName ADD COLUMN ${DbConstants.columnUpdatedAt} TEXT');
      await db.execute('ALTER TABLE $tableName ADD COLUMN ${DbConstants.columnDeletedAt} TEXT');
      await db.execute('ALTER TABLE $tableName ADD COLUMN ${DbConstants.columnSyncStatus} TEXT DEFAULT "pending"');
    } catch (e) {
      // Columns may already exist, ignore error
      print('Sync columns may already exist for $tableName: $e');
    }
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
        ${DbConstants.columnSyncId} TEXT,
        ${DbConstants.columnUpdatedAt} TEXT,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT DEFAULT 'pending'
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
        ${DbConstants.columnSyncId} TEXT,
        ${DbConstants.columnUpdatedAt} TEXT,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT DEFAULT 'pending'
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
        ${DbConstants.columnSyncId} TEXT,
        ${DbConstants.columnUpdatedAt} TEXT,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT DEFAULT 'pending',
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
        ${DbConstants.columnSyncId} TEXT,
        ${DbConstants.columnUpdatedAt} TEXT,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT DEFAULT 'pending',
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
        ${DbConstants.columnSyncId} TEXT,
        ${DbConstants.columnUpdatedAt} TEXT,
        ${DbConstants.columnDeletedAt} TEXT,
        ${DbConstants.columnSyncStatus} TEXT DEFAULT 'pending'
      )
    ''');
  }

  Future<void> _createSyncMetadataTable(Database db) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableSyncMetadata}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY,
        ${DbConstants.columnSupabaseUrl} TEXT,
        ${DbConstants.columnSupabaseKey} TEXT,
        ${DbConstants.columnLastSyncAt} TEXT
      )
    ''');
    
    // Insert default row
    await db.execute('''
      INSERT INTO ${DbConstants.tableSyncMetadata} (${DbConstants.columnId}, ${DbConstants.columnSupabaseUrl}, ${DbConstants.columnSupabaseKey}, ${DbConstants.columnLastSyncAt})
      VALUES (1, NULL, NULL, NULL)
    ''');
  }

  // Category CRUD with sync support
  Future<int> insertCategory(Category category) async {
    final db = await database;
    final map = category.toMap();
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
    return await db.insert(DbConstants.tableCategories, map);
  }

  Future<int> updateCategory(Category category) async {
    final db = await database;
    final map = category.toMap();
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
    return await db.update(
      DbConstants.tableCategories,
      map,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [category.id],
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
      where: '${DbConstants.columnSyncStatus} != ? AND ${DbConstants.columnDeletedAt} IS NULL',
      whereArgs: ['synced'],
    );
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.update(
      DbConstants.tableCategories,
      {
        DbConstants.columnDeletedAt: DateTime.now().toIso8601String(),
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
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
      where: '${DbConstants.columnSyncStatus} != ? OR ${DbConstants.columnDeletedAt} IS NOT NULL',
      whereArgs: ['synced'],
    );
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    final map = account.toMap();
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
        DbConstants.columnDeletedAt: DateTime.now().toIso8601String(),
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
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
      where: '${DbConstants.columnSyncStatus} != ? OR ${DbConstants.columnDeletedAt} IS NOT NULL',
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
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
        DbConstants.columnDeletedAt: DateTime.now().toIso8601String(),
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
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
    return await db.insert(
      DbConstants.tableRecurringTransactions,
      map,
    );
  }

  Future<int> updateRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    final map = transaction.toMap();
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
      where: '${DbConstants.columnSyncStatus} != ? OR ${DbConstants.columnDeletedAt} IS NOT NULL',
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
        DbConstants.columnDeletedAt: DateTime.now().toIso8601String(),
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
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
      where: '${DbConstants.columnSyncStatus} != ? OR ${DbConstants.columnDeletedAt} IS NOT NULL',
      whereArgs: ['synced'],
    );
    return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
  }

  Future<int> updateLoan(Loan loan) async {
    final db = await database;
    final map = loan.toMap();
    map[DbConstants.columnUpdatedAt] = DateTime.now().toIso8601String();
    map[DbConstants.columnSyncStatus] = 'pending';
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
        DbConstants.columnDeletedAt: DateTime.now().toIso8601String(),
        DbConstants.columnSyncStatus: 'pending',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Sync Status Updates
  Future<void> markAsSynced(String tableName, int localId, String syncId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        DbConstants.columnSyncId: syncId,
        DbConstants.columnSyncStatus: 'synced',
        DbConstants.columnUpdatedAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markAsFailed(String tableName, int localId) async {
    final db = await database;
    await db.update(
      tableName,
      {
        DbConstants.columnSyncStatus: 'failed',
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [localId],
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

  Future<void> saveSyncCredentials(String url, String key) async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {
        DbConstants.columnSupabaseUrl: url,
        DbConstants.columnSupabaseKey: key,
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  Future<void> updateLastSyncTime() async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {
        DbConstants.columnLastSyncAt: DateTime.now().toIso8601String(),
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
    );
  }

  Future<void> clearSyncCredentials() async {
    final db = await database;
    await db.update(
      DbConstants.tableSyncMetadata,
      {
        DbConstants.columnSupabaseUrl: null,
        DbConstants.columnSupabaseKey: null,
        DbConstants.columnLastSyncAt: null,
      },
      where: '${DbConstants.columnId} = ?',
      whereArgs: [1],
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
