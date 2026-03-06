import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/account_provider.dart';
import '../providers/currency_provider.dart';
import '../models/category.dart';

class SummaryCard extends StatelessWidget {
  const SummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final currencySymbol = _getCurrencySymbol(currency);
    final colorScheme = Theme.of(context).colorScheme;
    final formatter = NumberFormat.currency(
      symbol: currencySymbol,
      decimalDigits: 2,
    );

    // Consumer to listen to changes
    return Consumer2<TransactionProvider, AccountProvider>(
      builder: (context, txProvider, accProvider, child) {
        // Calculate income this month
        final now = DateTime.now();
        final currentMonthStart = DateTime(now.year, now.month, 1);
        final currentMonthTransactions = txProvider.transactions
            .where((tx) =>
                tx.date.isAfter(currentMonthStart) &&
                tx.date.isBefore(now.add(const Duration(days: 1))))
            .toList();

        final currentMonthIncome = currentMonthTransactions
            .where((tx) => tx.type == CategoryType.income)
            .fold<double>(0, (sum, tx) => sum + tx.amount);

        final currentMonthExpense = currentMonthTransactions
            .where((tx) => tx.type == CategoryType.expense)
            .fold<double>(0, (sum, tx) => sum + tx.amount);

        // Calculate income last month
        final lastMonthStart = DateTime(
          currentMonthStart.month == 1 ? now.year - 1 : now.year,
          currentMonthStart.month == 1 ? 12 : currentMonthStart.month - 1,
          1,
        );
        final lastMonthEnd = DateTime(
          currentMonthStart.year,
          currentMonthStart.month,
          1,
        );

        final lastMonthTransactions = txProvider.transactions
            .where((tx) =>
                tx.date.isAfter(lastMonthStart) &&
                tx.date.isBefore(lastMonthEnd))
            .toList();

        final lastMonthIncome = lastMonthTransactions
            .where((tx) => tx.type == CategoryType.income)
            .fold<double>(0, (sum, tx) => sum + tx.amount);

        final incomeChange = lastMonthIncome > 0
            ? ((currentMonthIncome - lastMonthIncome) / lastMonthIncome * 100)
            : 0;

        return Card(
          elevation: 0,
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  colorScheme.primaryContainer,
                  colorScheme.secondaryContainer,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Available Balance',
                          style: Theme.of(context)
                              .textTheme
                              .labelLarge
                              ?.copyWith(
                                color: colorScheme.onPrimaryContainer
                                    .withOpacity(0.7),
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          formatter.format(accProvider.totalBalance),
                          style: Theme.of(context)
                              .textTheme
                              .displayLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: colorScheme.onPrimaryContainer,
                                letterSpacing: -1,
                              ),
                        ),
                      ],
                    ),
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimaryContainer.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.wallet_outlined,
                        color: colorScheme.onPrimaryContainer
                            .withOpacity(0.5),
                        size: 28,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                // Divider
                Container(
                  height: 1,
                  color: colorScheme.onPrimaryContainer.withOpacity(0.1),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStat(
                      context: context,
                      label: 'Income',
                      amount: currentMonthIncome,
                      icon: Icons.trending_up_rounded,
                      color: colorScheme.tertiary,
                      formatter: formatter,
                      change: incomeChange.toStringAsFixed(0),
                      isPositive: incomeChange >= 0,
                    ),
                    Container(
                      height: 60,
                      width: 1,
                      color: colorScheme.onPrimaryContainer.withOpacity(0.12),
                    ),
                    _buildStat(
                      context: context,
                      label: 'Expense',
                      amount: currentMonthExpense,
                      icon: Icons.trending_down_rounded,
                      color: colorScheme.error,
                      formatter: formatter,
                      change: null,
                      isPositive: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStat({
    required BuildContext context,
    required String label,
    required double amount,
    required IconData icon,
    required Color color,
    required NumberFormat formatter,
    String? change,
    bool isPositive = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context)
                .colorScheme
                .onPrimaryContainer
                .withOpacity(0.65),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          formatter.format(amount),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
        if (change != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                isPositive
                    ? Icons.arrow_upward_rounded
                    : Icons.arrow_downward_rounded,
                size: 14,
                color: isPositive
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.error,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}$change%',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: isPositive
                      ? Theme.of(context).colorScheme.tertiary
                      : Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ],
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
