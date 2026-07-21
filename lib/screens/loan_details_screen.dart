import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/loan_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../constants/app_constants.dart';
import '../utils/icon_utils.dart';
import '../utils/amount_colors.dart';
import 'add_transaction_screen.dart';
import 'add_loan_screen.dart';
import 'loan_list_screen.dart';

class LoanDetailsScreen extends StatelessWidget {
  final int loanId;

  const LoanDetailsScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Details')),
      body: Consumer3<LoanProvider, TransactionProvider, CurrencyProvider>(
        builder: (context, loanProvider, txProvider, currencyProvider, child) {
          final currencySymbol =
              AppConstants.currencySymbols[currencyProvider.currency] ??
              currencyProvider.currency;

          final loan = loanProvider.loans.firstWhere(
            (l) => l.id == loanId,
            orElse: () => Loan(
              id: -1,
              title: 'Loan Not Found',
              amount: 0,
              interestRate: 0,
              tenureMonths: 0,
              type: LoanType.taken,
              startDate: DateTime.now(),
              emiAmount: 0,
              amountPaid: 0,
              isClosed: true,
            ),
          );

          if (loan.id == -1) {
            return const Center(child: Text('Loan not found'));
          }

          final linkedTransactions = txProvider.transactions
              .where((tx) => tx.loanId == loanId)
              .toList();

          linkedTransactions.sort((a, b) => b.date.compareTo(a.date));

          final progress = loan.amount <= 0
              ? 0.0
              : loan.amountPaid / loan.amount;
          final clampedProgress = progress.clamp(0.0, 1.0).toDouble();
          final colorScheme = Theme.of(context).colorScheme;
          final accent = colorScheme.primary;

          return Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, right: 16),
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AddLoanScreen(loan: loan),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Loan'),
                  ),
                ),
              ),

              Card(
                margin: const EdgeInsets.all(16),
                elevation: 0,
                color: colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 76,
                        height: 76,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: clampedProgress,
                              strokeWidth: 7,
                              backgroundColor: colorScheme.onPrimary.withValues(
                                alpha: 0.2,
                              ),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                colorScheme.onPrimary,
                              ),
                            ),
                            Text(
                              '${(clampedProgress * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    loan.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w800,
                                      color: colorScheme.onPrimary,
                                    ),
                                  ),
                                ),
                                if (!loan.isClosed)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: colorScheme.onPrimary.withValues(
                                        alpha: 0.18,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'ACTIVE',
                                      style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Remaining $currencySymbol${(loan.amount - loan.amountPaid).clamp(0.0, loan.amount).toStringAsFixed(0)} of $currencySymbol${loan.amount.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              if (!loan.isClosed)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_active_outlined,
                          color: colorScheme.onPrimaryContainer,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'EMI $currencySymbol${loan.emiAmount.toStringAsFixed(0)} due next',
                            style: TextStyle(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        FilledButton(
                          onPressed: () => showLoanPaymentDialog(
                            context,
                            loan,
                            loanProvider,
                          ),
                          child: const Text('Pay'),
                        ),
                      ],
                    ),
                  ),
                ),

              _EmiTimelineCard(
                loan: loan,
                transactions: linkedTransactions,
                currencySymbol: currencySymbol,
                accent: accent,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recent Transactions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              // Transaction List
              Expanded(
                child: linkedTransactions.isEmpty
                    ? const Center(
                        child: Text(
                          'No transactions linked to this loan yet.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: linkedTransactions.length,
                        itemBuilder: (context, index) {
                          final tx = linkedTransactions[index];
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

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(
                                category.colorValue,
                              ).withValues(alpha: 0.2),
                              child: Icon(
                                categoryIconData(
                                  category.iconCode,
                                  fontFamily: category.fontFamily,
                                  fontPackage: category.fontPackage,
                                ),
                                color: Color(category.colorValue),
                              ),
                            ),
                            title: Text(tx.title),
                            subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                            trailing: Text(
                              '$currencySymbol${tx.amount.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: amountColorForType(
                                  Theme.of(context).colorScheme,
                                  tx.type,
                                ),
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
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

}

class _EmiTimelineCard extends StatelessWidget {
  final Loan loan;
  final List<Transaction> transactions;
  final String currencySymbol;
  final Color accent;

  const _EmiTimelineCard({
    required this.loan,
    required this.transactions,
    required this.currencySymbol,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final paidEmis = loan.emiAmount <= 0
        ? transactions.length
        : (loan.amountPaid / loan.emiAmount).floor();
    final cappedPaidEmis = paidEmis.clamp(0, loan.tenureMonths).toInt();
    final visibleMonths = loan.tenureMonths.clamp(0, 12).toInt();
    final nextEmi = loan.isClosed ? loan.tenureMonths : cappedPaidEmis + 1;
    final nextDueDate = DateTime(
      loan.startDate.year,
      loan.startDate.month + cappedPaidEmis,
      loan.startDate.day,
    );

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline_rounded, color: accent),
                const SizedBox(width: 8),
                const Text(
                  'EMI timeline',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _TimelineStat(
                    label: 'Paid EMIs',
                    value: '$cappedPaidEmis/${loan.tenureMonths}',
                  ),
                ),
                Expanded(
                  child: _TimelineStat(
                    label: loan.isClosed ? 'Closed' : 'Next due',
                    value: loan.isClosed
                        ? 'Done'
                        : DateFormat.MMMd().format(nextDueDate),
                  ),
                ),
                Expanded(
                  child: _TimelineStat(
                    label: 'Next EMI',
                    value: loan.isClosed
                        ? '-'
                        : '#$nextEmi • $currencySymbol${loan.emiAmount.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < visibleMonths; index++)
              _EmiStepRow(
                emiNumber: index + 1,
                dueDate: DateTime(
                  loan.startDate.year,
                  loan.startDate.month + index + 1,
                  loan.startDate.day,
                ),
                amountLabel:
                    '$currencySymbol${loan.emiAmount.toStringAsFixed(0)}',
                status: index < cappedPaidEmis
                    ? _EmiStepStatus.paid
                    : index == cappedPaidEmis
                    ? _EmiStepStatus.next
                    : _EmiStepStatus.upcoming,
                accent: accent,
                isLast: index == visibleMonths - 1,
              ),
            if (loan.tenureMonths > 12)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${loan.tenureMonths - 12} more months',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TimelineStat extends StatelessWidget {
  final String label;
  final String value;

  const _TimelineStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
      ],
    );
  }
}

enum _EmiStepStatus { paid, next, upcoming }

class _EmiStepRow extends StatelessWidget {
  final int emiNumber;
  final DateTime dueDate;
  final String amountLabel;
  final _EmiStepStatus status;
  final Color accent;
  final bool isLast;

  const _EmiStepRow({
    required this.emiNumber,
    required this.dueDate,
    required this.amountLabel,
    required this.status,
    required this.accent,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isPaid = status == _EmiStepStatus.paid;
    final isNext = status == _EmiStepStatus.next;
    final textColor = status == _EmiStepStatus.upcoming
        ? colorScheme.onSurfaceVariant
        : colorScheme.onSurface;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Icon(
                isPaid ? Icons.check_circle : Icons.circle_outlined,
                size: 20,
                color: isPaid
                    ? accent
                    : isNext
                    ? accent
                    : colorScheme.outlineVariant,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'EMI #$emiNumber',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                  Text(
                    DateFormat.MMMd().format(dueDate),
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    amountLabel,
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
