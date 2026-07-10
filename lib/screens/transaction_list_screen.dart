import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/account_provider.dart';
import '../models/category.dart';
import '../models/account.dart';
import '../models/transaction.dart' as model;
import 'add_transaction_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/icon_utils.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  CategoryType? _filterType;
  DateTimeRange? _dateRange;
  String _searchQuery = '';

  void _showFilterSheet() {
    CategoryType? tempType = _filterType;
    DateTimeRange? tempRange = _dateRange;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                8,
                16,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter transactions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<CategoryType?>(
                    decoration: const InputDecoration(labelText: 'Type'),
                    initialValue: tempType,
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(
                        value: CategoryType.income,
                        child: Text('Income'),
                      ),
                      DropdownMenuItem(
                        value: CategoryType.expense,
                        child: Text('Expense'),
                      ),
                      DropdownMenuItem(
                        value: CategoryType.transfer,
                        child: Text('Transfer'),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        tempType = val;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: tempRange,
                      );
                      if (picked != null) {
                        setModalState(() {
                          tempRange = picked;
                        });
                      }
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      tempRange == null
                          ? 'Select date range'
                          : '${DateFormat.yMd().format(tempRange!.start)} - ${DateFormat.yMd().format(tempRange!.end)}',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterType = null;
                            _dateRange = null;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Clear'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _filterType = tempType;
                            _dateRange = tempRange;
                          });
                          Navigator.of(context).pop();
                        },
                        child: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final currencySymbol = _getCurrencySymbol(currency);
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/transactions'),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          var txs = provider.transactions;
          final categories = Provider.of<CategoryProvider>(
            context,
            listen: false,
          ).categories;
          final accounts = Provider.of<AccountProvider>(
            context,
            listen: false,
          ).accounts;

          if (_filterType != null) {
            txs = txs.where((tx) => tx.type == _filterType).toList();
          }

          if (_dateRange != null) {
            txs = txs
                .where(
                  (tx) =>
                      tx.date.isAfter(
                        _dateRange!.start.subtract(const Duration(days: 1)),
                      ) &&
                      tx.date.isBefore(
                        _dateRange!.end.add(const Duration(days: 1)),
                      ),
                )
                .toList();
          }

          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            txs = txs.where((tx) {
              final category = _categoryFor(tx.categoryId, categories);
              return tx.title.toLowerCase().contains(query) ||
                  (tx.notes?.toLowerCase().contains(query) ?? false) ||
                  category.name.toLowerCase().contains(query);
            }).toList();
          }
          final groups = _groupByDay(txs);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search title, notes, or category',
                    border: OutlineInputBorder(),
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: txs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Icon(
                                  Icons.search_off_outlined,
                                  size: 40,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                'No transactions found',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try adjusting filters or add a new transaction.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 20),
                              FilledButton.icon(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  Navigator.of(
                                    context,
                                  ).pushNamed('/add-transaction');
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Add transaction'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                                child: Row(
                                  children: [
                                    Text(
                                      _dayLabel(group.day).toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w700,
                                            letterSpacing: 0.5,
                                          ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      _formatSignedAmount(
                                        group.total,
                                        formatter,
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                            fontWeight: FontWeight.w600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: colorScheme.outlineVariant
                                        .withValues(alpha: 0.5),
                                    width: 0.5,
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Column(
                                  children: [
                                    for (
                                      var i = 0;
                                      i < group.transactions.length;
                                      i++
                                    ) ...[
                                      _TransactionRow(
                                        transaction: group.transactions[i],
                                        category: _categoryFor(
                                          group.transactions[i].categoryId,
                                          categories,
                                        ),
                                        formatter: formatter,
                                        onTap: () => _showTransactionDetails(
                                          context,
                                          group.transactions[i],
                                          _categoryFor(
                                            group.transactions[i].categoryId,
                                            categories,
                                          ),
                                          accounts,
                                          formatter,
                                          provider,
                                        ),
                                        onDelete: () async {
                                          final shouldDelete =
                                              await _confirmDelete(context);
                                          if (shouldDelete != true) return;
                                          await provider.deleteTransaction(
                                            group.transactions[i].id!,
                                          );
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Transaction deleted',
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      if (i != group.transactions.length - 1)
                                        Divider(
                                          height: 1,
                                          indent: 72,
                                          color: colorScheme.outlineVariant
                                              .withValues(alpha: 0.6),
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Category _categoryFor(int categoryId, List<Category> categories) {
    return categories.firstWhere(
      (c) => c.id == categoryId,
      orElse: () => Category(
        name: 'Unknown',
        iconCode: Icons.help_outline.codePoint,
        colorValue: Colors.grey.toARGB32(),
        type: CategoryType.expense,
        isCustom: false,
      ),
    );
  }

  List<_TransactionDayGroup> _groupByDay(List<model.Transaction> transactions) {
    final grouped = <DateTime, List<model.Transaction>>{};
    for (final tx in transactions) {
      final day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      grouped.putIfAbsent(day, () => []).add(tx);
    }

    return grouped.entries
        .map((entry) => _TransactionDayGroup(entry.key, entry.value))
        .toList();
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    if (day == today) return 'Today';
    if (day == yesterday) return 'Yesterday';
    return DateFormat.yMMMd().format(day);
  }

  String _formatSignedAmount(double amount, NumberFormat formatter) {
    if (amount > 0) return '+${formatter.format(amount)}';
    if (amount < 0) return '-${formatter.format(amount.abs())}';
    return formatter.format(0);
  }

  Future<bool?> _confirmDelete(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction?'),
        content: const Text(
          'Are you sure you want to delete this transaction?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: colorScheme.error)),
          ),
        ],
      ),
    );
  }

  void _showTransactionDetails(
    BuildContext context,
    model.Transaction tx,
    Category category,
    List<Account> accounts,
    NumberFormat formatter,
    TransactionProvider provider,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = Color(category.colorValue);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            24 + MediaQuery.of(sheetContext).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  categoryIconData(
                    category.iconCode,
                    fontFamily: category.fontFamily,
                    fontPackage: category.fontPackage,
                  ),
                  color: categoryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _detailAmount(tx, formatter),
                style: Theme.of(sheetContext).textTheme.headlineMedium
                    ?.copyWith(
                      color: _amountColor(tx.type, colorScheme),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                tx.title,
                textAlign: TextAlign.center,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    label: Text(category.name),
                    avatar: Icon(
                      categoryIconData(
                        category.iconCode,
                        fontFamily: category.fontFamily,
                        fontPackage: category.fontPackage,
                      ),
                      size: 16,
                      color: categoryColor,
                    ),
                    backgroundColor: categoryColor.withValues(alpha: 0.12),
                  ),
                  Chip(label: Text(_typeLabel(tx.type))),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                      label: 'Account',
                      value: _accountLabel(tx, accounts),
                    ),
                    _DetailRow(
                      label: 'Date',
                      value: DateFormat.yMMMd().format(tx.date),
                    ),
                    if (tx.originalAmount != null)
                      _DetailRow(
                        label: 'Original amount',
                        value:
                            '${tx.originalAmount!.toStringAsFixed(2)} ${tx.originalCurrency}',
                      ),
                    _DetailRow(
                      label: 'Note',
                      value: tx.notes?.isNotEmpty == true ? tx.notes! : '-',
                      showDivider: false,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.of(sheetContext).pop();
                        final shouldDelete = await _confirmDelete(context);
                        if (shouldDelete != true) return;
                        await provider.deleteTransaction(tx.id!);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Transaction deleted')),
                        );
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                AddTransactionScreen(transaction: tx),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _accountLabel(model.Transaction tx, List<Account> accounts) {
    final source = _accountName(tx.accountId, accounts);
    if (tx.type != CategoryType.transfer) return source;

    final destination = _accountName(tx.transferAccountId, accounts);
    return '$source -> $destination';
  }

  String _accountName(int? id, List<Account> accounts) {
    if (id == null) return 'Unlinked';
    return accounts
        .firstWhere(
          (account) => account.id == id,
          orElse: () => Account(
            name: 'Unknown account',
            type: AccountType.other,
            balance: 0,
          ),
        )
        .name;
  }

  String _typeLabel(CategoryType type) {
    switch (type) {
      case CategoryType.income:
        return 'Income';
      case CategoryType.expense:
        return 'Expense';
      case CategoryType.transfer:
        return 'Transfer';
    }
  }

  double _signedAmount(model.Transaction tx) {
    switch (tx.type) {
      case CategoryType.income:
        return tx.amount;
      case CategoryType.expense:
        return -tx.amount;
      case CategoryType.transfer:
        return 0;
    }
  }

  String _detailAmount(model.Transaction tx, NumberFormat formatter) {
    if (tx.type == CategoryType.transfer) return formatter.format(tx.amount);
    return _formatSignedAmount(_signedAmount(tx), formatter);
  }

  Color _amountColor(CategoryType type, ColorScheme colorScheme) {
    switch (type) {
      case CategoryType.income:
        return colorScheme.tertiary;
      case CategoryType.expense:
        return colorScheme.error;
      case CategoryType.transfer:
        return colorScheme.primary;
    }
  }

  String _getCurrencySymbol(String currencyCode) {
    switch (currencyCode) {
      case 'INR':
        return '₹';
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      default:
        return currencyCode;
    }
  }
}

class _TransactionDayGroup {
  final DateTime day;
  final List<model.Transaction> transactions;

  _TransactionDayGroup(this.day, this.transactions);

  double get total => transactions.fold(0, (sum, tx) {
    if (tx.type == CategoryType.income) return sum + tx.amount;
    if (tx.type == CategoryType.expense) return sum - tx.amount;
    return sum;
  });
}

class _TransactionRow extends StatelessWidget {
  final model.Transaction transaction;
  final Category category;
  final NumberFormat formatter;
  final VoidCallback onTap;
  final Future<void> Function() onDelete;

  const _TransactionRow({
    required this.transaction,
    required this.category,
    required this.formatter,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final categoryColor = Color(category.colorValue);

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: Icon(Icons.delete_outlined, color: colorScheme.onError),
      ),
      confirmDismiss: (_) async {
        await onDelete();
        return false;
      },
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: categoryColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(
            categoryIconData(
              category.iconCode,
              fontFamily: category.fontFamily,
              fontPackage: category.fontPackage,
            ),
            color: categoryColor,
            size: 22,
          ),
        ),
        title: Text(
          transaction.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${category.name} · ${DateFormat.yMMMd().format(transaction.date)}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _displayAmount(transaction, formatter),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: _displayColor(transaction.type, colorScheme),
                fontWeight: FontWeight.w700,
              ),
            ),
            if (transaction.originalAmount != null)
              Text(
                '${transaction.originalAmount!.toStringAsFixed(2)} ${transaction.originalCurrency}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _displayAmount(
    model.Transaction transaction,
    NumberFormat formatter,
  ) {
    if (transaction.type == CategoryType.income) {
      return '+${formatter.format(transaction.amount)}';
    }
    if (transaction.type == CategoryType.expense) {
      return '-${formatter.format(transaction.amount)}';
    }
    return formatter.format(transaction.amount);
  }

  static Color _displayColor(CategoryType type, ColorScheme colorScheme) {
    if (type == CategoryType.income) return colorScheme.tertiary;
    if (type == CategoryType.expense) return colorScheme.error;
    return colorScheme.primary;
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _DetailRow({
    required this.label,
    required this.value,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: colorScheme.outlineVariant,
          ),
      ],
    );
  }
}
