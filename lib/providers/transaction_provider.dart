import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/loan.dart';
import '../services/database_service.dart';
import '../constants/app_constants.dart';

class TransactionProvider with ChangeNotifier {
  List<Transaction> _transactions = [];
  bool _isLoading = false;
  String? _error;
  final DatabaseService _dbService = DatabaseService();

  List<Transaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchTransactions() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _transactions = await _dbService.getTransactions();
      _error = null;
    } catch (e) {
      _error = AppConstants.errorLoadingTransactions;
      debugPrint('Error fetching transactions: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double get totalIncome => _transactions
      .where((tx) => tx.type == CategoryType.income)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get totalExpense => _transactions
      .where((tx) => tx.type == CategoryType.expense)
      .fold(0.0, (sum, tx) => sum + tx.amount);

  double get balance => totalIncome - totalExpense;

  Future<void> addTransaction(Transaction transaction) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _dbService.insertTransaction(transaction);

      // Update account balances
      if (transaction.type == CategoryType.transfer) {
        if (transaction.accountId != null) {
          await _updateAccountBalance(
            transaction.accountId!,
            -transaction.amount,
          );
        }
        if (transaction.transferAccountId != null) {
          await _updateAccountBalance(
            transaction.transferAccountId!,
            transaction.amount,
          );
        }
      } else {
        // Income or Expense
        if (transaction.accountId != null) {
          if (transaction.type == CategoryType.income) {
            await _updateAccountBalance(
              transaction.accountId!,
              transaction.amount,
            );
          } else {
            await _updateAccountBalance(
              transaction.accountId!,
              -transaction.amount,
            );
          }
        }
      }

      // Update loan balance if transaction is linked
      if (transaction.loanId != null) {
        await _updateLoanBalance(transaction.loanId!, transaction.amount);
      }

      await fetchTransactions();
    } catch (e) {
      _error = AppConstants.errorAddingTransaction;
      debugPrint('Error adding transaction: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final transaction = _transactions.firstWhere(
        (tx) => tx.id == id,
        orElse: () => throw Exception('Transaction with id $id not found'),
      );

      // Revert account balances
      if (transaction.type == CategoryType.transfer) {
        if (transaction.accountId != null) {
          await _updateAccountBalance(transaction.accountId!, transaction.amount);
        }
        if (transaction.transferAccountId != null) {
          await _updateAccountBalance(
            transaction.transferAccountId!,
            -transaction.amount,
          );
        }
      } else {
        // Income or Expense
        if (transaction.accountId != null) {
          if (transaction.type == CategoryType.income) {
            await _updateAccountBalance(
              transaction.accountId!,
              -transaction.amount,
            );
          } else {
            await _updateAccountBalance(
              transaction.accountId!,
              transaction.amount,
            );
          }
        }
      }

      // Revert loan balance if transaction is linked
      if (transaction.loanId != null) {
        await _updateLoanBalance(transaction.loanId!, -transaction.amount);
      }

      await _dbService.deleteTransaction(id);
      await fetchTransactions();
    } catch (e) {
      _error = AppConstants.errorDeletingTransaction;
      debugPrint('Error deleting transaction: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateTransaction(Transaction transaction) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // 1. Revert old transaction effect
      final oldTransaction = _transactions.firstWhere(
        (tx) => tx.id == transaction.id,
      );

      if (oldTransaction.type == CategoryType.transfer) {
        if (oldTransaction.accountId != null) {
          await _updateAccountBalance(
            oldTransaction.accountId!,
            oldTransaction.amount,
          );
        }
        if (oldTransaction.transferAccountId != null) {
          await _updateAccountBalance(
            oldTransaction.transferAccountId!,
            -oldTransaction.amount,
          );
        }
      } else {
        if (oldTransaction.accountId != null) {
          if (oldTransaction.type == CategoryType.income) {
            await _updateAccountBalance(
              oldTransaction.accountId!,
              -oldTransaction.amount,
            );
          } else {
            await _updateAccountBalance(
              oldTransaction.accountId!,
              oldTransaction.amount,
            );
          }
        }
      }

      // 2. Update transaction in DB
      await _dbService.updateTransaction(transaction);

      // 3. Apply new transaction effect
      if (transaction.type == CategoryType.transfer) {
        if (transaction.accountId != null) {
          await _updateAccountBalance(
            transaction.accountId!,
            -transaction.amount,
          );
        }
        if (transaction.transferAccountId != null) {
          await _updateAccountBalance(
            transaction.transferAccountId!,
            transaction.amount,
          );
        }
      } else {
        if (transaction.accountId != null) {
          if (transaction.type == CategoryType.income) {
            await _updateAccountBalance(
              transaction.accountId!,
              transaction.amount,
            );
          } else {
            await _updateAccountBalance(
              transaction.accountId!,
              -transaction.amount,
            );
          }
        }
      }

      // 4. Update loan balances
      if (oldTransaction.loanId != null) {
        await _updateLoanBalance(oldTransaction.loanId!, -oldTransaction.amount);
      }
      if (transaction.loanId != null) {
        await _updateLoanBalance(transaction.loanId!, transaction.amount);
      }

      await fetchTransactions();
    } catch (e) {
      _error = AppConstants.errorUpdatingTransaction;
      debugPrint('Error updating transaction: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _updateLoanBalance(int loanId, double delta) async {
    final loans = await _dbService.getLoans();
    try {
      final loan = loans.firstWhere((l) => l.id == loanId);
      double newAmountPaid = loan.amountPaid + delta;

      // Ensure non-negative
      if (newAmountPaid < 0) newAmountPaid = 0;

      final updatedLoan = Loan(
        id: loan.id,
        title: loan.title,
        amount: loan.amount,
        interestRate: loan.interestRate,
        tenureMonths: loan.tenureMonths,
        type: loan.type,
        startDate: loan.startDate,
        emiAmount: loan.emiAmount,
        amountPaid: newAmountPaid,
        isClosed: newAmountPaid >= loan.amount, // Close if paid off
        notes: loan.notes,
      );

      await _dbService.updateLoan(updatedLoan);
    } catch (e) {
      debugPrint('Error updating loan balance: $e');
    }
  }

  Future<void> _updateAccountBalance(int accountId, double delta) async {
    final accounts = await _dbService.getAccounts();
    try {
      final account = accounts.firstWhere((a) => a.id == accountId);
      final updatedAccount = Account(
        id: account.id,
        name: account.name,
        type: account.type,
        balance: account.balance + delta,
      );
      await _dbService.updateAccount(updatedAccount);
    } catch (e) {
      debugPrint('Error updating account balance: $e');
    }
  }
}
