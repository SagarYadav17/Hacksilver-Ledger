/// Database constants for table and column names
class DbConstants {
  // Table names
  static const String tableCategories = 'categories';
  static const String tableAccounts = 'accounts';
  static const String tableTransactions = 'transactions';
  static const String tableRecurringTransactions = 'recurring_transactions';
  static const String tableLoans = 'loans';

  // Common columns
  static const String columnId = 'id';
  static const String columnName = 'name';
  static const String columnDate = 'date';
  static const String columnType = 'type';

  // Categories columns
  static const String columnCategoryIconCode = 'iconCode';
  static const String columnCategoryFontFamily = 'fontFamily';
  static const String columnCategoryFontPackage = 'fontPackage';
  static const String columnCategoryColorValue = 'colorValue';
  static const String columnCategoryIsCustom = 'isCustom';

  // Accounts columns
  static const String columnAccountBalance = 'balance';

  // Transactions columns
  static const String columnTransactionTitle = 'title';
  static const String columnTransactionAmount = 'amount';
  static const String columnTransactionCategoryId = 'categoryId';
  static const String columnTransactionAccountId = 'accountId';
  static const String columnTransactionTransferAccountId = 'transferAccountId';
  static const String columnTransactionNotes = 'notes';
  static const String columnTransactionOriginalAmount = 'originalAmount';
  static const String columnTransactionOriginalCurrency = 'originalCurrency';
  static const String columnTransactionLoanId = 'loanId';

  // Recurring Transactions columns
  static const String columnRecurringTransactionTitle = 'title';
  static const String columnRecurringTransactionAmount = 'amount';
  static const String columnRecurringTransactionCategoryId = 'categoryId';
  static const String columnRecurringTransactionAccountId = 'accountId';
  static const String columnRecurringTransactionFrequency = 'frequency';
  static const String columnRecurringTransactionNextDate = 'nextDate';
  static const String columnRecurringTransactionIsActive = 'isActive';
  static const String columnRecurringTransactionNotes = 'notes';

  // Loans columns
  static const String columnLoanPrincipal = 'principal';
  static const String columnLoanInterestRate = 'interestRate';
  static const String columnLoanStartDate = 'startDate';
  static const String columnLoanEndDate = 'endDate';
  static const String columnLoanLender = 'lender';
  static const String columnLoanBorrower = 'borrower';
  static const String columnLoanAmountPaid = 'amountPaid';
  static const String columnLoanAccountId = 'accountId';

  // Database name
  static const String databaseName = 'hacksilver_ledger.db';
  static const int databaseVersion = 1;
}
