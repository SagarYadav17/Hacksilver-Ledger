import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/account.dart';
import '../models/category.dart';
import '../models/transaction.dart' as model;
import '../providers/transaction_provider.dart';
import '../screens/add_transaction_screen.dart';
import '../utils/amount_colors.dart';
import '../utils/icon_utils.dart';

Future<void> showTransactionDetailsSheet(
  BuildContext context, {
  required model.Transaction transaction,
  required Category category,
  required List<Account> accounts,
  required NumberFormat formatter,
  required TransactionProvider provider,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final categoryColor = Color(category.colorValue);

  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (sheetContext) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          8,
          20,
          24 + MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                categoryIconData(
                  category.iconCode,
                  fontFamily: category.fontFamily,
                  fontPackage: category.fontPackage,
                ),
                color: categoryColor,
                size: 32,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _detailAmount(transaction, formatter),
              style: Theme.of(sheetContext).textTheme.headlineMedium?.copyWith(
                color: amountColorForType(colorScheme, transaction.type),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              transaction.title,
              textAlign: TextAlign.center,
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(category.name),
                  avatar: Icon(
                    categoryIconData(
                      category.iconCode,
                      fontFamily: category.fontFamily,
                      fontPackage: category.fontPackage,
                    ),
                    size: 16,
                    color: categoryColor,
                  ),
                  backgroundColor: categoryColor.withValues(alpha: 0.12),
                ),
                Chip(label: Text(_typeLabel(transaction.type))),
              ],
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Account',
                    value: _accountLabel(transaction, accounts),
                  ),
                  _DetailRow(
                    label: 'Date',
                    value: DateFormat.yMMMd().format(transaction.date),
                  ),
                  if (transaction.originalAmount != null)
                    _DetailRow(
                      label: 'Original amount',
                      value:
                          '${transaction.originalAmount!.toStringAsFixed(2)} ${transaction.originalCurrency}',
                    ),
                  _DetailRow(
                    label: 'Note',
                    value: transaction.notes?.isNotEmpty == true
                        ? transaction.notes!
                        : '-',
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddTransactionScreen(duplicateFrom: transaction),
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy_outlined),
                    label: const Text('Duplicate'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                    ),
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      final shouldDelete = await _confirmDelete(context);
                      if (shouldDelete != true) return;
                      await provider.deleteTransaction(transaction.id!);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaction deleted')),
                      );
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Delete'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(transaction: transaction),
                    ),
                  );
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit'),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<bool?> _confirmDelete(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Delete Transaction?'),
      content: const Text('Are you sure you want to delete this transaction?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text('Delete', style: TextStyle(color: colorScheme.error)),
        ),
      ],
    ),
  );
}

String _accountLabel(model.Transaction tx, List<Account> accounts) {
  final source = _accountName(tx.accountId, accounts);
  if (tx.type != CategoryType.transfer) return source;
  final destination = _accountName(tx.transferAccountId, accounts);
  return '$source -> $destination';
}

String _accountName(int? id, List<Account> accounts) {
  if (id == null) return 'Unlinked';
  return accounts
      .firstWhere(
        (account) => account.id == id,
        orElse: () => Account(name: 'Unknown account', type: AccountType.other, balance: 0),
      )
      .name;
}

String _typeLabel(CategoryType type) {
  switch (type) {
    case CategoryType.income:
      return 'Income';
    case CategoryType.expense:
      return 'Expense';
    case CategoryType.transfer:
      return 'Transfer';
  }
}

double _signedAmount(model.Transaction tx) {
  switch (tx.type) {
    case CategoryType.income:
      return tx.amount;
    case CategoryType.expense:
      return -tx.amount;
    case CategoryType.transfer:
      return 0;
  }
}

String _formatSignedAmount(double amount, NumberFormat formatter) {
  if (amount > 0) return '+${formatter.format(amount)}';
  if (amount < 0) return '-${formatter.format(amount.abs())}';
  return formatter.format(0);
}

String _detailAmount(model.Transaction tx, NumberFormat formatter) {
  if (tx.type == CategoryType.transfer) return formatter.format(tx.amount);
  return _formatSignedAmount(_signedAmount(tx), formatter);
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool showDivider;

  const _DetailRow({required this.label, required this.value, this.showDivider = true});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(height: 1, indent: 16, endIndent: 16, color: colorScheme.outlineVariant),
      ],
    );
  }
}
