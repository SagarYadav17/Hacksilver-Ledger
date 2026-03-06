import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/transaction.dart'
    as model; // Alias to avoid conflict if needed, though not strictly necessary here
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
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${DbConstants.tableCategories}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnName} TEXT,
        ${DbConstants.columnCategoryIconCode} INTEGER,
        ${DbConstants.columnCategoryFontFamily} TEXT,
        ${DbConstants.columnCategoryFontPackage} TEXT,
        ${DbConstants.columnCategoryColorValue} INTEGER,
        ${DbConstants.columnCategoryType} INTEGER,
        ${DbConstants.columnCategoryIsCustom} INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE ${DbConstants.tableAccounts}(
        ${DbConstants.columnId} INTEGER PRIMARY KEY AUTOINCREMENT,
        ${DbConstants.columnName} TEXT,
        type INTEGER,
        ${DbConstants.columnAccountBalance} REAL
      )
    ''');

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
        FOREIGN KEY(${DbConstants.columnTransactionCategoryId}) REFERENCES ${DbConstants.tableCategories}(${DbConstants.columnId}),
        FOREIGN KEY(${DbConstants.columnTransactionAccountId}) REFERENCES ${DbConstants.tableAccounts}(${DbConstants.columnId})
      )
    ''');

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
        FOREIGN KEY(${DbConstants.columnRecurringTransactionCategoryId}) REFERENCES ${DbConstants.tableCategories}(${DbConstants.columnId})
      )
    ''');

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
        notes TEXT
      )
    ''');
  }

  // Category CRUD
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert(DbConstants.tableCategories, category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(DbConstants.tableCategories);
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableCategories,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Account CRUD
  Future<int> insertAccount(Account account) async {
    final db = await database;
    return await db.insert(DbConstants.tableAccounts, account.toMap());
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(DbConstants.tableAccounts);
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      DbConstants.tableAccounts,
      account.toMap(),
      where: '${DbConstants.columnId} = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableAccounts,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Transaction CRUD
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.insert(DbConstants.tableTransactions, transaction.toMap());
  }

  Future<List<model.Transaction>> getTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      DbConstants.tableTransactions,
      orderBy: '${DbConstants.columnDate} DESC',
    );
    return List.generate(
      maps.length,
      (i) => model.Transaction.fromMap(maps[i]),
    );
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.update(
      DbConstants.tableTransactions,
      transaction.toMap(),
      where: '${DbConstants.columnId} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableTransactions,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Recurring Transaction CRUD
  Future<int> insertRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    return await db.insert(
        DbConstants.tableRecurringTransactions, transaction.toMap());
  }

  Future<int> updateRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    return await db.update(
      DbConstants.tableRecurringTransactions,
      transaction.toMap(),
      where: '${DbConstants.columnId} = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(DbConstants.tableRecurringTransactions);
    return List.generate(
      maps.length,
      (i) => RecurringTransaction.fromMap(maps[i]),
    );
  }

  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableRecurringTransactions,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
    );
  }

  // Loan CRUD

  Future<int> insertLoan(Loan loan) async {
    final db = await database;
    return await db.insert(DbConstants.tableLoans, loan.toMap());
  }

  Future<List<Loan>> getLoans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps =
        await db.query(DbConstants.tableLoans);
    return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
  }

  Future<int> updateLoan(Loan loan) async {
    final db = await database;
    return await db.update(
      DbConstants.tableLoans,
      loan.toMap(),
      where: '${DbConstants.columnId} = ?',
      whereArgs: [loan.id],
    );
  }

  Future<int> deleteLoan(int id) async {
    final db = await database;
    return await db.delete(
      DbConstants.tableLoans,
      where: '${DbConstants.columnId} = ?',
      whereArgs: [id],
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
