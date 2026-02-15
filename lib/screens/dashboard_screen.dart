import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/loan_provider.dart';
import '../models/category.dart';
import '../widgets/summary_card.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/account_summary.dart';
import 'add_transaction_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
      body: Column(
        children: [
          const SummaryCard(),
          const AccountSummary(),
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, provider, child) {
                if (provider.transactions.isEmpty) {
                  return const Center(
                    child: Text(
                      'No transactions yet.\nTap + to add one!',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: provider.transactions.length > 10
                      ? 10
                      : provider.transactions.length,
                  itemBuilder: (context, index) {
                    final tx = provider.transactions[index];
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
                              fontFamily:
                                  category.fontFamily ?? 'MaterialIcons',
                              fontPackage: category.fontPackage,
                            ),
                            color: Color(category.colorValue),
                          ),
                        ),
                        title: Text(tx.title),
                        subtitle: Text(tx.date.toString().substring(0, 10)),
                        trailing: Text(
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
}
