import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/loan_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/security_provider.dart';
import '../models/category.dart';
import '../widgets/summary_card.dart';
import '../widgets/account_summary.dart';
import '../widgets/app_bottom_nav.dart';
import 'add_transaction_screen.dart';
import '../utils/icon_utils.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = Provider.of<CurrencyProvider>(context).currency;
    final securityProvider = Provider.of<SecurityProvider>(context);
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
      bottomNavigationBar: const AppBottomNav(currentRoute: '/'),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            Provider.of<TransactionProvider>(
              context,
              listen: false,
            ).fetchTransactions(),
            Provider.of<AccountProvider>(
              context,
              listen: false,
            ).fetchAccounts(),
            Provider.of<LoanProvider>(context, listen: false).fetchLoans(),
          ]);
          return Future.delayed(const Duration(milliseconds: 500));
        },
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            const SummaryCard(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                children: [
                  _QuickActionButton(
                    label: 'Expense',
                    icon: Icons.arrow_downward_rounded,
                    color: colorScheme.error,
                    onTap: () =>
                        _openAddTransaction(context, CategoryType.expense),
                  ),
                  const SizedBox(width: 8),
                  _QuickActionButton(
                    label: 'Income',
                    icon: Icons.arrow_upward_rounded,
                    color: colorScheme.tertiary,
                    onTap: () =>
                        _openAddTransaction(context, CategoryType.income),
                  ),
                  const SizedBox(width: 8),
                  _QuickActionButton(
                    label: 'Transfer',
                    icon: Icons.swap_horiz_rounded,
                    color: colorScheme.primary,
                    onTap: () =>
                        _openAddTransaction(context, CategoryType.transfer),
                  ),
                  const SizedBox(width: 8),
                  _QuickActionButton(
                    label: 'EMI',
                    icon: Icons.calendar_month_rounded,
                    color: colorScheme.secondary,
                    onTap: () => _openQuickAction(context, '/loans'),
                  ),
                ],
              ),
            ),
            const _CashflowCard(),
            const AccountSummary(),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Recent Transactions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your latest activity',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/transactions');
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    label: const Text('View all'),
                  ),
                ],
              ),
            ),
            Consumer<TransactionProvider>(
              builder: (context, provider, child) {
                if (provider.transactions.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Icon(
                            Icons.receipt_long_outlined,
                            size: 56,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Start Tracking Your Money',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Add your first transaction to begin your finance journey',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 28),
                        FilledButton.icon(
                          onPressed: () {
                            _openAddTransaction(context, CategoryType.expense);
                          },
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Create First Transaction'),
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
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
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
                            colorValue: Colors.grey.toARGB32(),
                            type: CategoryType.expense,
                            isCustom: false,
                          ),
                        );

                    return Dismissible(
                      key: ValueKey(tx.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: Icon(
                          Icons.delete_outlined,
                          color: colorScheme.onError,
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
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: Text(
                                  'Delete',
                                  style: TextStyle(color: colorScheme.error),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        provider.deleteTransaction(tx.id!);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: const Text('Transaction deleted')),
                        );
                      },
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  AddTransactionScreen(transaction: tx),
                            ),
                          );
                        },
                        child: Card(
                          elevation: 0,
                          color: colorScheme.surface,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 12.0,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Color(
                                      category.colorValue,
                                    ).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    categoryIconData(
                                      category.iconCode,
                                      fontFamily: category.fontFamily,
                                      fontPackage: category.fontPackage,
                                    ),
                                    color: Color(category.colorValue),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tx.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w500,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        category.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      securityProvider.maskAmount(
                                        formatter.format(tx.amount),
                                      ),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color:
                                                tx.type == CategoryType.income
                                                ? colorScheme.tertiary
                                                : tx.type ==
                                                      CategoryType.expense
                                                ? colorScheme.error
                                                : colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat.yMMMd().format(tx.date),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openAddTransaction(context, CategoryType.expense);
        },
        icon: const Icon(Icons.add_rounded, size: 24),
        label: const Text('Add Transaction'),
        elevation: 8,
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

  void _openQuickAction(BuildContext context, String route) {
    HapticFeedback.lightImpact();
    Navigator.of(context).pushNamed(route);
  }

  void _openAddTransaction(BuildContext context, CategoryType initialType) {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: initialType),
      ),
    );
  }
}

class _CashflowCard extends StatelessWidget {
  const _CashflowCard();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Consumer<TransactionProvider>(
      builder: (context, provider, child) {
        final months = _lastSixMonths();
        final buckets = months.map((month) {
          final txs = provider.transactions.where(
            (tx) => tx.date.year == month.year && tx.date.month == month.month,
          );
          final income = txs
              .where((tx) => tx.type == CategoryType.income)
              .fold<double>(0, (sum, tx) => sum + tx.amount);
          final expense = txs
              .where((tx) => tx.type == CategoryType.expense)
              .fold<double>(0, (sum, tx) => sum + tx.amount);
          return _CashflowBucket(month, income, expense);
        }).toList();

        final maxAmount = buckets.fold<double>(
          0,
          (max, bucket) => [
            max,
            bucket.income,
            bucket.expense,
          ].reduce((a, b) => a > b ? a : b),
        );

        return Card(
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          color: colorScheme.surfaceContainerHighest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Cashflow',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '6 months',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 144,
                  child: BarChart(
                    BarChartData(
                      maxY: maxAmount == 0 ? 1 : maxAmount * 1.15,
                      alignment: BarChartAlignment.spaceAround,
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 28,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= buckets.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat.MMM().format(buckets[index].month),
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      barGroups: [
                        for (var i = 0; i < buckets.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: buckets[i].income,
                                width: 9,
                                borderRadius: BorderRadius.circular(4),
                                color: colorScheme.primary,
                              ),
                              BarChartRodData(
                                toY: buckets[i].expense,
                                width: 9,
                                borderRadius: BorderRadius.circular(4),
                                color: colorScheme.outlineVariant,
                              ),
                            ],
                          ),
                      ],
                    ),
                    duration: const Duration(milliseconds: 250),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _LegendDot(label: 'Income', color: colorScheme.primary),
                    const SizedBox(width: 16),
                    _LegendDot(
                      label: 'Expense',
                      color: colorScheme.outlineVariant,
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

  List<DateTime> _lastSixMonths() {
    final now = DateTime.now();
    return List.generate(6, (index) {
      final monthOffset = now.month - 5 + index;
      return DateTime(now.year, monthOffset, 1);
    });
  }
}

class _CashflowBucket {
  final DateTime month;
  final double income;
  final double expense;

  const _CashflowBucket(this.month, this.income, this.expense);
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;

  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Material(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 21),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
