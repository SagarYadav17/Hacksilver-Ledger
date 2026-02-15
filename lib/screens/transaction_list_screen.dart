import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
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

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Filter Transactions'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<CategoryType>(
                decoration: const InputDecoration(labelText: 'Type'),
                initialValue: _filterType,
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
                  setState(() {
                    _filterType = val;
                  });
                  Navigator.of(context).pop();
                  _showFilterDialog(); // Re-open to show state change or just close.
                  // Better UX: update state inside dialog or use StatefulBuilder.
                  // For simplicity, just update parent state and let user see result.
                },
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _dateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _dateRange = picked;
                    });
                    if (mounted) Navigator.of(context).pop();
                  }
                },
                child: Text(
                  _dateRange == null
                      ? 'Select Date Range'
                      : '${DateFormat.yMd().format(_dateRange!.start)} - ${DateFormat.yMd().format(_dateRange!.end)}',
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  setState(() {
                    _filterType = null;
                    _dateRange = null;
                  });
                  Navigator.of(context).pop();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_alt),
            onPressed: _showFilterDialog,
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
            return const Center(child: Text('No transactions found'));
          }

          return ListView.builder(
            itemCount: txs.length,
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
                        tx.amount.toStringAsFixed(2),
                        style: TextStyle(
                          color: tx.type == CategoryType.income
                              ? Colors.green
                              : tx.type == CategoryType.expense
                              ? Colors.red
                              : Colors.blue,
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
}
