import 'package:flutter/foundation.dart';
import '../models/loan.dart';
import '../services/database_service.dart';
import '../constants/app_constants.dart';

class LoanProvider with ChangeNotifier {
  final DatabaseService _databaseService;
  List<Loan> _loans = [];
  bool _isLoading = false;
  String? _error;

  LoanProvider(this._databaseService);

  List<Loan> get loans => _loans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Calculate total outstanding amount for loans taken
  double get totalLoansTakenAmount {
    return _loans
        .where((l) => l.type == LoanType.taken && !l.isClosed)
        .fold(0.0, (sum, item) => sum + (item.amount - item.amountPaid));
  }

  // Calculate total outstanding amount for loans given
  double get totalLoansGivenAmount {
    return _loans
        .where((l) => l.type == LoanType.given && !l.isClosed)
        .fold(0.0, (sum, item) => sum + (item.amount - item.amountPaid));
  }

  Future<void> fetchLoans() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _loans = await _databaseService.getLoans();
      _error = null;
    } catch (e) {
      _error = AppConstants.errorLoadingLoans;
      debugPrint('Error fetching loans: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addLoan(Loan loan) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.insertLoan(loan);
      await fetchLoans();
    } catch (e) {
      _error = 'Failed to add loan';
      debugPrint('Error adding loan: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateLoan(Loan loan) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.updateLoan(loan);
      await fetchLoans();
    } catch (e) {
      _error = 'Failed to update loan';
      debugPrint('Error updating loan: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteLoan(int id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _databaseService.deleteLoan(id);
      await fetchLoans();
    } catch (e) {
      _error = 'Failed to delete loan';
      debugPrint('Error deleting loan: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to record a payment (this could be enhanced to link with Transactions)
  Future<void> payLoanInstallment(Loan loan, double amount) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final updatedLoan = Loan(
        id: loan.id,
        title: loan.title,
        amount: loan.amount,
        interestRate: loan.interestRate,
        tenureMonths: loan.tenureMonths,
        type: loan.type,
        startDate: loan.startDate,
        emiAmount: loan.emiAmount,
        amountPaid: loan.amountPaid + amount,
        isClosed:
            (loan.amountPaid + amount) >= loan.amount, // Simple closure logic
        notes: loan.notes,
      );
      await updateLoan(updatedLoan);
    } catch (e) {
      _error = 'Failed to record loan payment';
      debugPrint('Error recording loan payment: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
