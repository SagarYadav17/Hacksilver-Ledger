import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../models/account.dart';
import 'add_account_screen.dart';

import '../widgets/custom_drawer.dart';

class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      drawer: const CustomDrawer(currentRoute: '/accounts'),
      body: Consumer<AccountProvider>(
        builder: (context, provider, child) {
          final accounts = provider.accounts;

          if (accounts.isEmpty) {
            return const Center(child: Text('No accounts added yet'));
          }

          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              return Dismissible(
                key: ValueKey(account.id),
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
                      title: const Text('Delete Account?'),
                      content: const Text(
                        'Are you sure you want to delete this account? This will not delete associated transactions but they will be unlinked.',
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
                  provider.deleteAccount(account.id!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${account.name} deleted')),
                  );
                },
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(
                      context,
                    ).colorScheme.primaryContainer,
                    child: Icon(
                      _getIconForType(account.type),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(account.name),
                  subtitle: Text(account.type.toString().split('.').last),
                  trailing: Text(
                    '₹${account.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  onTap: () {
                    // Navigate to edit screen (AddAccountScreen acts as edit too)
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (ctx) => AddAccountScreen(account: account),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add-account');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  IconData _getIconForType(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return Icons.payments_outlined;
      case AccountType.bank:
        return Icons.account_balance_outlined;
      case AccountType.creditCard:
        return Icons.credit_card_outlined;
      case AccountType.other:
        return Icons.account_balance_wallet_outlined;
    }
  }
}
