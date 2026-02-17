import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/currency_provider.dart';
import '../models/category.dart';
import '../widgets/summary_card.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/account_summary.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

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
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () {
              Provider.of<TransactionProvider>(
                context,
                listen: false,
              ).fetchTransactions();
              Provider.of<AccountProvider>(
                context,
                listen: false,
              ).fetchAccounts();
              Provider.of<LoanProvider>(context, listen: false).fetchLoans();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Refreshing data...'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(currentRoute: '/'),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 96),
        children: [
          const SummaryCard(),
          const AccountSummary(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pushNamed('/transactions');
                  },
                  child: const Text('View all'),
                ),
              ],
            ),
          ),
          Consumer<TransactionProvider>(
            builder: (context, provider, child) {
              if (provider.transactions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No transactions yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add your first transaction to see it here.',
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
                );
              }

              final items = provider.transactions.take(5).toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final tx = items[index];
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
                      child: const Icon(
                        Icons.delete_outlined,
                        color: Colors.white,
                      ),
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
                      trailing: Text(
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
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (ctx) =>
                                AddTransactionScreen(transaction: tx),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add-transaction');
        },
        child: const Icon(Icons.add),
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
