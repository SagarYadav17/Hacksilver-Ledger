import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/recurring_transaction_provider.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../widgets/custom_drawer.dart';

class RecurringTransactionListScreen extends StatelessWidget {
  const RecurringTransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recurring Transactions')),
      drawer: const CustomDrawer(currentRoute: '/recurring-transactions'),
      body: Consumer<RecurringTransactionProvider>(
        builder: (context, provider, child) {
          final transactions = provider.recurringTransactions;
          if (transactions.isEmpty) {
            return const Center(child: Text('No recurring transactions yet.'));
          }

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final tx = transactions[index];
              final isExpense = tx.type == CategoryType.expense;

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

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                  title: Text(
                    tx.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${tx.frequency.toString().split('.').last.toUpperCase()} • Next: ${DateFormat.MMMd().format(tx.nextDueDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '\$${tx.amount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isExpense ? Colors.red : Colors.green,
                          fontSize: 16,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outlined,
                          color: Colors.grey,
                        ),
                        onPressed: () {
                          provider.deleteRecurringTransaction(tx.id!);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add-recurring-transaction');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
