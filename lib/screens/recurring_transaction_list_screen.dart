import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../providers/category_provider.dart';
import '../utils/icon_utils.dart';
import '../utils/amount_colors.dart';

class RecurringTransactionListScreen extends StatelessWidget {
  const RecurringTransactionListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Recurring')),
      body: Consumer<RecurringTransactionProvider>(
        builder: (context, provider, child) {
          final transactions = provider.recurringTransactions;
          if (transactions.isEmpty) {
            return _EmptyRecurring(
              onAdd: () =>
                  Navigator.of(context).pushNamed('/add-recurring-transaction'),
            );
          }

          final active = transactions.where((tx) => tx.isActive).toList();
          final scheduledThisMonth = active.fold<double>(
            0,
            (sum, tx) => sum + tx.amount,
          );

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: plannedColor(colorScheme).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'PLANNED THIS MONTH',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: plannedColor(colorScheme),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${scheduledThisMonth.toStringAsFixed(0)}',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: plannedColor(colorScheme),
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${active.length} active ${active.length == 1 ? 'schedule' : 'schedules'}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'UPCOMING',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.7,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              for (final tx in transactions)
                _RecurringRow(
                  key: ValueKey(tx.id),
                  tx: tx,
                  onToggle: () => provider.toggleRecurringTransaction(tx),
                  onDelete: () => provider.deleteRecurringTransaction(tx.id!),
                ),
              if (active.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  'GENERATED THIS MONTH',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                _GeneratedThisMonth(active: active),
              ],
            ],
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

class _RecurringRow extends StatelessWidget {
  final dynamic tx;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _RecurringRow({
    super.key,
    required this.tx,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final category = Provider.of<CategoryProvider>(context, listen: false)
        .categories
        .firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => Category(
            name: 'Unknown',
            iconCode: Icons.help_outline.codePoint,
            colorValue: Colors.grey.toARGB32(),
            type: CategoryType.expense,
            isCustom: false,
          ),
        );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: tx.isActive ? colorScheme.surfaceContainerLow : null,
        borderRadius: BorderRadius.circular(20),
        border: !tx.isActive
            ? Border.all(color: colorScheme.outlineVariant, width: 1)
            : Border.all(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Color(category.colorValue).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                categoryIconData(
                  category.iconCode,
                  fontFamily: category.fontFamily,
                  fontPackage: category.fontPackage,
                ),
                color: Color(category.colorValue),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: tx.isActive ? null : colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '\$${tx.amount.toStringAsFixed(0)}',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: amountColorForType(colorScheme, tx.type),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  if (tx.isActive)
                    Text(
                      '${tx.frequency.toString().split('.').last} · next ${DateFormat.MMMd().format(tx.nextDueDate)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else
                    Row(
                      children: [
                        Icon(
                          Icons.pause_circle_outline,
                          size: 14,
                          color: Colors.amber.shade800,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "Paused · won't generate entries",
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.amber.shade800),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Switch(value: tx.isActive, onChanged: (_) => onToggle()),
            IconButton(
              icon: Icon(
                Icons.delete_outline,
                color: colorScheme.onSurfaceVariant,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRecurring extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyRecurring({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: plannedColor(scheme).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.calendar_month_outlined,
                size: 34,
                color: plannedColor(scheme),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Plan recurring money',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Add bills, income, and other regular entries so they never slip by.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add schedule'),
            ),
          ],
        ),
      ),
    );
  }
}

class _GeneratedThisMonth extends StatelessWidget {
  final List<dynamic> active;

  const _GeneratedThisMonth({required this.active});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final activeIds = active.map((r) => r.id).toSet();

    return Consumer<TransactionProvider>(
      builder: (context, txProvider, child) {
        final generated = txProvider.transactions.where((t) {
          if (t.date.isBefore(monthStart)) return false;
          return t.recurringId != null && activeIds.contains(t.recurringId);
        }).toList()..sort((a, b) => b.date.compareTo(a.date));

        if (generated.isEmpty) {
          return Text(
            'No entries generated yet this month.',
            style: TextStyle(color: colorScheme.onSurfaceVariant),
          );
        }

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (final t in generated)
                ListTile(
                  dense: true,
                  leading: Icon(
                    Icons.check_circle_outline,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    '${t.title} — auto-added ${DateFormat.MMMd().format(t.date)}',
                  ),
                  trailing: Text(
                    t.amount.toStringAsFixed(0),
                    style: TextStyle(
                      color: amountColorForType(colorScheme, t.type),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
