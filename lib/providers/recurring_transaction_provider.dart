import 'package:flutter/material.dart';
import '../models/recurring_transaction.dart';
import '../services/database_service.dart';
import '../models/transaction.dart' as model;

class RecurringTransactionProvider with ChangeNotifier {
  List<RecurringTransaction> _recurringTransactions = [];
  final DatabaseService _dbService = DatabaseService();

  List<RecurringTransaction> get recurringTransactions =>
      _recurringTransactions;

  Future<void> fetchRecurringTransactions() async {
    _recurringTransactions = await _dbService.getRecurringTransactions();
    notifyListeners();
  }

  Future<void> addRecurringTransaction(RecurringTransaction transaction) async {
    await _dbService.insertRecurringTransaction(transaction);
    await fetchRecurringTransactions();
  }

  Future<void> deleteRecurringTransaction(int id) async {
    await _dbService.deleteRecurringTransaction(id);
    await fetchRecurringTransactions();
  }

  Future<void> toggleRecurringTransaction(
    RecurringTransaction transaction,
  ) async {
    await _dbService.updateRecurringTransaction(
      transaction.copyWith(isActive: !transaction.isActive),
    );
    await fetchRecurringTransactions();
  }

  Future<void> checkAndGenerateRecurringTransactions() async {
    await fetchRecurringTransactions();
    final now = DateTime.now();

    for (var recurring in _recurringTransactions) {
      if (recurring.isActive &&
          (recurring.nextDueDate.isBefore(now) ||
              recurring.nextDueDate.isAtSameMomentAs(now))) {
        // Generate transaction
        var currentDate = recurring.nextDueDate;

        // Loop to catch up if multiple periods passed (e.g. app wasn't opened for months)
        while (currentDate.isBefore(now) || currentDate.isAtSameMomentAs(now)) {
          final newTx = model.Transaction(
            title: recurring.title,
            amount: recurring.amount,
            date: currentDate,
            type: recurring.type,
            categoryId: recurring.categoryId,
            accountId: recurring.accountId,
            notes: recurring.notes,
            recurringId: recurring.id,
          );

          await _dbService.insertTransaction(newTx);

          // Calculate next due date
          currentDate = recurring.calculateNextDueDate(currentDate);
        }

        // Update recurring transaction with new nextDueDate but keep original ID
        final updatedRecurring = recurring.copyWith(nextDueDate: currentDate);
        await _dbService.updateRecurringTransaction(updatedRecurring);
      }
    }
    await fetchRecurringTransactions();
  }
}
