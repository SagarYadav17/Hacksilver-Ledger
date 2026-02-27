/// App-wide constants
class AppConstants {
  // Currency
  static const String defaultCurrency = 'USD';
  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'JPY': '¥',
    'CAD': 'C\$',
    'AUD': 'A\$',
  };

  // Pagination
  static const int transactionsPageSize = 20;
  static const int accountsPageSize = 50;

  // Durations
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration refreshDuration = Duration(milliseconds: 500);
  static const Duration shortAnimationDuration = Duration(milliseconds: 300);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 500);

  // Sizing
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;

  static const double defaultBorderRadius = 12.0;
  static const double largeBorderRadius = 16.0;

  // Constraints
  static const int maxTitleLength = 100;
  static const int maxNotesLength = 500;
  static const double maxTransactionAmount = 999999999.99;
  static const double minTransactionAmount = 0.01;

  // Error messages
  static const String errorLoadingTransactions = 'Failed to load transactions';
  static const String errorLoadingAccounts = 'Failed to load accounts';
  static const String errorLoadingCategories = 'Failed to load categories';
  static const String errorLoadingLoans = 'Failed to load loans';
  static const String errorAddingTransaction = 'Failed to add transaction';
  static const String errorUpdatingTransaction = 'Failed to update transaction';
  static const String errorDeletingTransaction = 'Failed to delete transaction';
  static const String errorAddingAccount = 'Failed to add account';
  static const String errorUpdatingAccount = 'Failed to update account';
  static const String errorDeletingAccount = 'Failed to delete account';
  static const String errorGeneric = 'An error occurred. Please try again.';

  // Success messages
  static const String successAddTransaction = 'Transaction added successfully';
  static const String successUpdateTransaction = 'Transaction updated successfully';
  static const String successDeleteTransaction = 'Transaction deleted successfully';
  static const String successAddAccount = 'Account added successfully';
  static const String successUpdateAccount = 'Account updated successfully';
  static const String successDeleteAccount = 'Account deleted successfully';
}
