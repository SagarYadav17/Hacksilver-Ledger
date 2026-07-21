import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/account_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/security_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/account.dart';
import '../models/category.dart';
import 'add_account_screen.dart';
import 'add_transaction_screen.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/sparkline.dart';
import '../utils/amount_colors.dart';

class AccountListScreen extends StatelessWidget {
  const AccountListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/accounts'),
      body: Consumer3<AccountProvider, CurrencyProvider, TransactionProvider>(
        builder: (context, provider, currencyProvider, txProvider, child) {
          final accounts = provider.accounts;
          final colorScheme = Theme.of(context).colorScheme;
          final securityProvider = context.watch<SecurityProvider>();
          final formatter = NumberFormat.currency(
            symbol: _getCurrencySymbol(currencyProvider.currency),
            decimalDigits: 2,
          );

          if (accounts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 56,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No accounts yet',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add your first wallet, bank, or card to start tracking balances.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () =>
                          Navigator.of(context).pushNamed('/add-account'),
                      icon: const Icon(Icons.add),
                      label: const Text('Add account'),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Card(
                elevation: 0,
                color: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Total balance',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(
                                    color: colorScheme.onPrimary.withValues(
                                      alpha: 0.72,
                                    ),
                                    letterSpacing: 0.4,
                                  ),
                            ),
                          ),
                          Icon(
                            Icons.account_balance_wallet_outlined,
                            color: colorScheme.onPrimary.withValues(
                              alpha: 0.78,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          securityProvider.maskAmount(
                            formatter.format(provider.totalBalance),
                          ),
                          style: Theme.of(context).textTheme.displayMedium
                              ?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -1,
                              ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.tonalIcon(
                        onPressed: () => _moveMoney(context, accounts.length),
                        icon: const Icon(Icons.swap_horiz_rounded),
                        label: const Text('Move money'),
                        style: FilledButton.styleFrom(
                          backgroundColor: colorScheme.onPrimary.withValues(
                            alpha: 0.14,
                          ),
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Accounts',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              for (final account in accounts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Dismissible(
                    key: ValueKey(account.id),
                    direction: DismissDirection.endToStart,
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: colorScheme.error,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.delete_outlined,
                        color: colorScheme.onError,
                      ),
                    ),
                    confirmDismiss: (direction) async {
                      return await showDialog<bool>(
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
                          ) ??
                          false;
                    },
                    onDismissed: (direction) {
                      provider.deleteAccount(account.id!);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('${account.name} deleted')),
                      );
                    },
                    child: Card(
                      elevation: 0,
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: BorderSide(
                          color: colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  AddAccountScreen(account: account),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  _getIconForType(account.type),
                                  color: colorScheme.onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      account.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _accountTypeLabel(account.type),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    securityProvider.maskAmount(
                                      formatter.format(account.balance),
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: _getBalanceColor(
                                            colorScheme,
                                            account.balance,
                                          ),
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Sparkline(
                                    values: _recentDeltas(
                                      txProvider,
                                      account.id,
                                    ),
                                    barColor: incomeColor(colorScheme),
                                    downColor: expenseColor(colorScheme),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
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

  void _moveMoney(BuildContext context, int accountCount) {
    if (accountCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add another account to move money.')),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const AddTransactionScreen(
          initialType: CategoryType.transfer,
        ),
      ),
    );
  }

  List<double> _recentDeltas(TransactionProvider txProvider, int? accountId) {
    if (accountId == null) return const [];
    final related = txProvider.transactions
        .where((tx) => tx.accountId == accountId || tx.transferAccountId == accountId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final recent = related.take(4).toList().reversed;
    return [
      for (final tx in recent)
        switch (tx.type) {
          CategoryType.income => tx.amount,
          CategoryType.expense => -tx.amount,
          CategoryType.transfer =>
            tx.accountId == accountId ? -tx.amount : tx.amount,
        },
    ];
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

  String _accountTypeLabel(AccountType type) {
    switch (type) {
      case AccountType.cash:
        return 'Cash';
      case AccountType.bank:
        return 'Bank';
      case AccountType.creditCard:
        return 'Credit card';
      case AccountType.other:
        return 'Other';
    }
  }

  Color _getBalanceColor(ColorScheme colorScheme, double balance) {
    if (balance >= 0) return incomeColor(colorScheme);
    return expenseColor(colorScheme);
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
