import 'package:flutter/material.dart';
import '../models/account.dart';
import '../services/database_service.dart';
import '../constants/app_constants.dart';

class AccountProvider with ChangeNotifier {
  List<Account> _accounts = [];
  bool _isLoading = false;
  String? _error;
  final DatabaseService _dbService = DatabaseService();

  List<Account> get accounts => _accounts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> fetchAccounts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _accounts = await _dbService.getAccounts();
      _error = null;
    } catch (e) {
      _error = AppConstants.errorLoadingAccounts;
      debugPrint('Error fetching accounts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  double get totalBalance =>
      _accounts.fold(0.0, (sum, item) => sum + item.balance);

  Future<void> addAccount(Account account) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _dbService.insertAccount(account);
      await fetchAccounts();
    } catch (e) {
      _error = AppConstants.errorAddingAccount;
      debugPrint('Error adding account: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> initAccounts() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await fetchAccounts();
      if (_accounts.isEmpty) {
        // Seed default account
        await _dbService.insertAccount(
          Account(name: 'Cash', type: AccountType.cash, balance: 0.0),
        );
        await fetchAccounts();
      }
    } catch (e) {
      _error = AppConstants.errorLoadingAccounts;
      debugPrint('Error initializing accounts: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateAccount(Account account) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _dbService.updateAccount(account);
      await fetchAccounts();
    } catch (e) {
      _error = AppConstants.errorUpdatingAccount;
      debugPrint('Error updating account: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAccount(int id) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _dbService.deleteAccount(id);
      await fetchAccounts();
    } catch (e) {
      _error = AppConstants.errorDeletingAccount;
      debugPrint('Error deleting account: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
