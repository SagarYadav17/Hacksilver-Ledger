import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/category.dart';
import '../models/transaction.dart'
    as model; // Alias to avoid conflict if needed, though not strictly necessary here
import '../models/account.dart';
import '../models/recurring_transaction.dart';
import '../models/loan.dart';

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
    String path = join(await getDatabasesPath(), 'hacksilver_ledger.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        iconCode INTEGER,
        fontFamily TEXT,
        fontPackage TEXT,
        colorValue INTEGER,
        type INTEGER,
        isCustom INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE accounts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT,
        type INTEGER,
        balance REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        date TEXT,
        type INTEGER,
        categoryId INTEGER,
        accountId INTEGER,
        notes TEXT,
        originalAmount REAL,
        originalCurrency TEXT,
        loanId INTEGER,
        transferAccountId INTEGER,
        FOREIGN KEY(categoryId) REFERENCES categories(id),
        FOREIGN KEY(accountId) REFERENCES accounts(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE recurring_transactions(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        type INTEGER,
        categoryId INTEGER,
        accountId INTEGER,
        frequency INTEGER,
        startDate TEXT,
        nextDueDate TEXT,
        isActive INTEGER,
        notes TEXT,
        FOREIGN KEY(categoryId) REFERENCES categories(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE loans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT,
        amount REAL,
        interestRate REAL,
        tenureMonths INTEGER,
        type INTEGER,
        startDate TEXT,
        emiAmount REAL,
        amountPaid REAL,
        isClosed INTEGER,
        notes TEXT
      )
    ''');
  }

  // Costants for tables
  static const String tableCategories = 'categories';
  static const String tableAccounts = 'accounts';
  static const String tableTransactions = 'transactions';
  static const String tableRecurringTransactions = 'recurring_transactions';

  // Category CRUD
  Future<int> insertCategory(Category category) async {
    final db = await database;
    return await db.insert(tableCategories, category.toMap());
  }

  Future<List<Category>> getCategories() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableCategories);
    return List.generate(maps.length, (i) => Category.fromMap(maps[i]));
  }

  Future<int> deleteCategory(int id) async {
    final db = await database;
    // Optional: Check if used in transactions before delete, or cascade.
    // For now, simple delete.
    return await db.delete(tableCategories, where: 'id = ?', whereArgs: [id]);
  }

  // Account CRUD
  Future<int> insertAccount(Account account) async {
    final db = await database;
    return await db.insert(tableAccounts, account.toMap());
  }

  Future<List<Account>> getAccounts() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableAccounts);
    return List.generate(maps.length, (i) => Account.fromMap(maps[i]));
  }

  Future<int> updateAccount(Account account) async {
    final db = await database;
    return await db.update(
      tableAccounts,
      account.toMap(),
      where: 'id = ?',
      whereArgs: [account.id],
    );
  }

  Future<int> deleteAccount(int id) async {
    final db = await database;
    return await db.delete(tableAccounts, where: 'id = ?', whereArgs: [id]);
  }

  // Transaction CRUD
  Future<int> insertTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.insert(tableTransactions, transaction.toMap());
  }

  Future<List<model.Transaction>> getTransactions() async {
    final db = await database;
    // Order by date descending
    final List<Map<String, dynamic>> maps = await db.query(
      tableTransactions,
      orderBy: 'date DESC',
    );
    return List.generate(
      maps.length,
      (i) => model.Transaction.fromMap(maps[i]),
    );
  }

  Future<int> updateTransaction(model.Transaction transaction) async {
    final db = await database;
    return await db.update(
      tableTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<int> deleteTransaction(int id) async {
    final db = await database;
    return await db.delete(tableTransactions, where: 'id = ?', whereArgs: [id]);
  }

  // Recurring Transaction CRUD
  Future<int> insertRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    return await db.insert(tableRecurringTransactions, transaction.toMap());
  }

  Future<int> updateRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    final db = await database;
    return await db.update(
      tableRecurringTransactions,
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      tableRecurringTransactions,
    );
    return List.generate(
      maps.length,
      (i) => RecurringTransaction.fromMap(maps[i]),
    );
  }

  Future<int> deleteRecurringTransaction(int id) async {
    final db = await database;
    return await db.delete(
      tableRecurringTransactions,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Loan CRUD
  static const String tableLoans = 'loans';

  Future<int> insertLoan(Loan loan) async {
    final db = await database;
    return await db.insert(tableLoans, loan.toMap());
  }

  Future<List<Loan>> getLoans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(tableLoans);
    return List.generate(maps.length, (i) => Loan.fromMap(maps[i]));
  }

  Future<int> updateLoan(Loan loan) async {
    final db = await database;
    return await db.update(
      tableLoans,
      loan.toMap(),
      where: 'id = ?',
      whereArgs: [loan.id],
    );
  }

  Future<int> deleteLoan(int id) async {
    final db = await database;
    return await db.delete(tableLoans, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
