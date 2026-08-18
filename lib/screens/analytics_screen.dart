import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/security_provider.dart';
import '../models/category.dart';
import '../constants/app_constants.dart';
import '../utils/icon_utils.dart';
import '../utils/amount_colors.dart';

enum _Period { threeMonths, sixMonths, twelveMonths }

extension on _Period {
  int get months => switch (this) {
    _Period.threeMonths => 3,
    _Period.sixMonths => 6,
    _Period.twelveMonths => 12,
  };
  String get label => switch (this) {
    _Period.threeMonths => '3M',
    _Period.sixMonths => '6M',
    _Period.twelveMonths => '12M',
  };
}

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  _Period _period = _Period.sixMonths;
  bool _comparePreviousPeriod = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final currency = context.watch<CurrencyProvider>().currency;
    final formatter = NumberFormat.currency(
      symbol: AppConstants.currencySymbols[currency] ?? currency,
      decimalDigits: 0,
    );
    final securityProvider = context.watch<SecurityProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: Consumer2<TransactionProvider, CategoryProvider>(
        builder: (context, txProvider, categoryProvider, child) {
          final now = DateTime.now();
          final periodStart = DateTime(
            now.year,
            now.month - _period.months + 1,
            1,
          );
          final periodTxs = txProvider.transactions
              .where((t) => !t.date.isBefore(periodStart))
              .toList();

          final income = periodTxs
              .where((t) => t.type == CategoryType.income)
              .fold<double>(0, (sum, t) => sum + t.amount);
          final expense = periodTxs
              .where((t) => t.type == CategoryType.expense)
              .fold<double>(0, (sum, t) => sum + t.amount);
          final savingsRate = income <= 0 ? 0.0 : (income - expense) / income;
          final previousPeriodStart = DateTime(
            periodStart.year,
            periodStart.month - _period.months,
            1,
          );
          final previousPeriodTxs = txProvider.transactions
              .where(
                (t) =>
                    !t.date.isBefore(previousPeriodStart) &&
                    t.date.isBefore(periodStart),
              )
              .toList();
          final previousIncome = previousPeriodTxs
              .where((t) => t.type == CategoryType.income)
              .fold<double>(0, (sum, t) => sum + t.amount);
          final previousExpense = previousPeriodTxs
              .where((t) => t.type == CategoryType.expense)
              .fold<double>(0, (sum, t) => sum + t.amount);

          final months = List.generate(
            _period.months,
            (i) => DateTime(now.year, now.month - _period.months + 1 + i, 1),
          );
          final buckets = months.map((month) {
            final txs = periodTxs.where(
              (t) => t.date.year == month.year && t.date.month == month.month,
            );
            final inc = txs
                .where((t) => t.type == CategoryType.income)
                .fold<double>(0, (sum, t) => sum + t.amount);
            final exp = txs
                .where((t) => t.type == CategoryType.expense)
                .fold<double>(0, (sum, t) => sum + t.amount);
            return (month: month, income: inc, expense: exp);
          }).toList();
          final maxBucket = buckets.fold<double>(
            0,
            (max, b) =>
                [max, b.income, b.expense].reduce((a, b) => a > b ? a : b),
          );

          final expenseTxs = periodTxs
              .where((t) => t.type == CategoryType.expense)
              .toList();
          final byCategory = <int, double>{};
          for (final t in expenseTxs) {
            byCategory[t.categoryId] =
                (byCategory[t.categoryId] ?? 0) + t.amount;
          }
          final categoryEntries = byCategory.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final palette = [
            incomeColor(colorScheme),
            plannedColor(colorScheme),
            groupingColor(colorScheme),
            expenseColor(colorScheme),
            colorScheme.primaryContainer,
            colorScheme.secondaryContainer,
          ];

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              SegmentedButton<_Period>(
                segments: _Period.values
                    .map((p) => ButtonSegment(value: p, label: Text(p.label)))
                    .toList(),
                selected: {_period},
                onSelectionChanged: (selection) =>
                    setState(() => _period = selection.first),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilterChip(
                  label: Text('Compare previous ${_period.label}'),
                  selected: _comparePreviousPeriod,
                  onSelected: (selected) =>
                      setState(() => _comparePreviousPeriod = selected),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryTile(
                      label: 'Income',
                      value: securityProvider.maskAmount(
                        formatter.format(income),
                      ),
                      color: incomeColor(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Expense',
                      value: securityProvider.maskAmount(
                        formatter.format(expense),
                      ),
                      color: expenseColor(colorScheme),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryTile(
                      label: 'Savings rate',
                      value:
                          '${(savingsRate * 100).clamp(-999, 999).toStringAsFixed(0)}%',
                      color: groupingColor(colorScheme),
                    ),
                  ),
                ],
              ),
              if (_comparePreviousPeriod) ...[
                const SizedBox(height: 16),
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Change vs previous ${_period.label}',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${DateFormat.yMMMd().format(previousPeriodStart)} – '
                          '${DateFormat.yMMMd().format(periodStart.subtract(const Duration(days: 1)))}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _ComparisonTile(
                                label: 'Income',
                                value: securityProvider.maskAmount(
                                  _formatDifference(
                                    income - previousIncome,
                                    formatter,
                                  ),
                                ),
                                color: incomeColor(colorScheme),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ComparisonTile(
                                label: 'Expense',
                                value: securityProvider.maskAmount(
                                  _formatDifference(
                                    expense - previousExpense,
                                    formatter,
                                  ),
                                ),
                                color: expenseColor(colorScheme),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ComparisonTile(
                                label: 'Net',
                                value: securityProvider.maskAmount(
                                  _formatDifference(
                                    (income - expense) -
                                        (previousIncome - previousExpense),
                                    formatter,
                                  ),
                                ),
                                color: groupingColor(colorScheme),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trend',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 160,
                        child: BarChart(
                          BarChartData(
                            maxY: maxBucket == 0 ? 1 : maxBucket * 1.15,
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
                                        DateFormat.MMM().format(
                                          buckets[index].month,
                                        ),
                                        style: Theme.of(
                                          context,
                                        ).textTheme.labelSmall,
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
                                      width: 8,
                                      borderRadius: BorderRadius.circular(4),
                                      color: incomeColor(colorScheme),
                                    ),
                                    BarChartRodData(
                                      toY: buckets[i].expense,
                                      width: 8,
                                      borderRadius: BorderRadius.circular(4),
                                      color: expenseColor(colorScheme),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Spending by category',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 16),
                      if (categoryEntries.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No expenses in this period.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        )
                      else ...[
                        SizedBox(
                          height: 160,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: [
                                for (var i = 0; i < categoryEntries.length; i++)
                                  PieChartSectionData(
                                    value: categoryEntries[i].value,
                                    color: palette[i % palette.length],
                                    showTitle: false,
                                    radius: 34,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        for (var i = 0; i < categoryEntries.length; i++)
                          _CategoryLegendRow(
                            category: categoryProvider.categories.firstWhere(
                              (c) => c.id == categoryEntries[i].key,
                              orElse: () => Category(
                                name: 'Unknown',
                                iconCode: Icons.help_outline.codePoint,
                                colorValue: Colors.grey.toARGB32(),
                                type: CategoryType.expense,
                                isCustom: false,
                              ),
                            ),
                            amount: categoryEntries[i].value,
                            share: expense == 0
                                ? 0
                                : categoryEntries[i].value / expense,
                            swatchColor: palette[i % palette.length],
                            formatter: formatter,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _formatDifference(double amount, NumberFormat formatter) {
    if (amount > 0) return '+${formatter.format(amount)}';
    if (amount < 0) return '-${formatter.format(amount.abs())}';
    return formatter.format(0);
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: color),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ComparisonTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _CategoryLegendRow extends StatelessWidget {
  final Category category;
  final double amount;
  final double share;
  final Color swatchColor;
  final NumberFormat formatter;

  const _CategoryLegendRow({
    required this.category,
    required this.amount,
    required this.share,
    required this.swatchColor,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: swatchColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            categoryIconData(
              category.iconCode,
              fontFamily: category.fontFamily,
              fontPackage: category.fontPackage,
            ),
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(category.name)),
          Text(
            '${(share * 100).toStringAsFixed(0)}%',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Text(
            formatter.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
