import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../models/category.dart';
import 'add_transaction_screen.dart';
import '../widgets/custom_drawer.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  CategoryType? _filterType;
  DateTimeRange? _dateRange;

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
                    value: tempType,
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
      drawer: const CustomDrawer(currentRoute: '/transactions'),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, child) {
          var txs = provider.transactions;

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

          if (txs.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No transactions found',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Try adjusting filters or add a new transaction.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pushNamed('/add-transaction');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add transaction'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: txs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (context, index) {
              final tx = txs[index];
              final category =
                  Provider.of<CategoryProvider>(
                    context,
                    listen: false,
                  ).categories.firstWhere(
                    (c) => c.id == tx.categoryId,
                    orElse: () => Category(
                      name: 'Unknown',
                      iconCode: Icons.help_outline.codePoint,
                      colorValue: Colors.grey.value,
                      type: CategoryType.expense,
                      isCustom: false,
                    ),
                  );

              return Dismissible(
                key: ValueKey(tx.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: const Icon(Icons.delete_outlined, color: Colors.white),
                ),
                confirmDismiss: (direction) async {
                  return await showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Transaction?'),
                      content: const Text(
                        'Are you sure you want to delete this transaction?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(false),
                          child: const Text('No'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(true),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),
                  );
                },
                onDismissed: (direction) {
                  provider.deleteTransaction(tx.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Transaction deleted')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Color(
                      category.colorValue,
                    ).withOpacity(0.2),
                    child: Icon(
                      IconData(
                        category.iconCode,
                        fontFamily: category.fontFamily ?? 'MaterialIcons',
                        fontPackage: category.fontPackage,
                      ),
                      color: Color(category.colorValue),
                    ),
                  ),
                  title: Text(tx.title),
                  subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatter.format(tx.amount),
                        style: TextStyle(
                          color: tx.type == CategoryType.income
                              ? colorScheme.tertiary
                              : tx.type == CategoryType.expense
                              ? colorScheme.error
                              : colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (tx.originalAmount != null)
                        Text(
                          '${tx.originalAmount!.toStringAsFixed(2)} ${tx.originalCurrency}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => AddTransactionScreen(transaction: tx),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
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
