import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/loan_provider.dart';
import '../models/loan.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/account_provider.dart';
import '../constants/app_constants.dart';
import '../widgets/app_bottom_nav.dart';
import 'loan_details_screen.dart';

class LoanListScreen extends StatefulWidget {
  const LoanListScreen({super.key});

  @override
  State<LoanListScreen> createState() => _LoanListScreenState();
}

class _LoanListScreenState extends State<LoanListScreen> {
  LoanType _selectedType = LoanType.taken;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<LoanProvider>().fetchLoans();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loans')),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/loans'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: SegmentedButton<LoanType>(
              segments: const [
                ButtonSegment(value: LoanType.taken, label: Text('Borrowed')),
                ButtonSegment(value: LoanType.given, label: Text('Lent')),
              ],
              selected: {_selectedType},
              onSelectionChanged: (selection) {
                setState(() => _selectedType = selection.first);
              },
            ),
          ),
          _LoanStatTiles(type: _selectedType),
          Expanded(child: LoanList(type: _selectedType)),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).pushNamed('/add-loan');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _LoanStatTiles extends StatelessWidget {
  final LoanType type;
  const _LoanStatTiles({required this.type});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Consumer2<LoanProvider, CurrencyProvider>(
      builder: (context, loanProvider, currencyProvider, child) {
        final currencySymbol =
            AppConstants.currencySymbols[currencyProvider.currency] ??
            currencyProvider.currency;
        final loans = loanProvider.loans
            .where((l) => l.type == type && !l.isClosed)
            .toList();
        final outstanding = loans.fold<double>(
          0,
          (sum, l) => sum + (l.amount - l.amountPaid).clamp(0, l.amount),
        );

        DateTime? nextEmiDate;
        for (final loan in loans) {
          final paidCount = loan.emiAmount <= 0
              ? 0
              : (loan.amountPaid / loan.emiAmount).floor();
          final due = DateTime(
            loan.startDate.year,
            loan.startDate.month + paidCount + 1,
            loan.startDate.day,
          );
          if (nextEmiDate == null || due.isBefore(nextEmiDate)) {
            nextEmiDate = due;
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              Expanded(
                child: _StatTile(
                  label: type == LoanType.taken ? 'You owe' : 'Owed to you',
                  value: '$currencySymbol${outstanding.toStringAsFixed(0)}',
                  color: colorScheme.secondaryContainer,
                  onColor: colorScheme.onSecondaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatTile(
                  label: 'Next EMI',
                  value: nextEmiDate != null
                      ? DateFormat.MMMd().format(nextEmiDate)
                      : '-',
                  color: colorScheme.secondaryContainer,
                  onColor: colorScheme.onSecondaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color onColor;

  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: onColor),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class LoanList extends StatelessWidget {
  final LoanType type;
  const LoanList({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Consumer3<LoanProvider, CurrencyProvider, TransactionProvider>(
      builder: (context, provider, currencyProvider, txProvider, child) {
        final currencySymbol =
            AppConstants.currencySymbols[currencyProvider.currency] ??
            currencyProvider.currency;
        final loans = provider.loans.where((l) => l.type == type).toList();

        if (loans.isEmpty) {
          return const Center(child: Text('No loans found.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            final linkedTransactions = txProvider.transactions
                .where((tx) => tx.loanId == loan.id)
                .toList();

            return _LoanCard(
              loan: loan,
              type: type,
              currencySymbol: currencySymbol,
              paymentCount: linkedTransactions.length,
              onOpen: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => LoanDetailsScreen(loanId: loan.id!),
                  ),
                );
              },
              onPay: loan.isClosed
                  ? null
                  : () => showLoanPaymentDialog(context, loan, provider),
              onDelete: () => provider.deleteLoan(loan.id!),
            );
          },
        );
      },
    );
  }
}

void showLoanPaymentDialog(
  BuildContext context,
  Loan loan,
  LoanProvider loanProvider,
) {
    final amountController = TextEditingController(
      text: loan.emiAmount.toStringAsFixed(2),
    );
    final commentsController = TextEditingController();
    DateTime selectedDate = DateTime.now();
    int? selectedAccountId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setState) {
          final currencyProvider = context.read<CurrencyProvider>();
          final accountProvider = context.read<AccountProvider>();
          final currencySymbol =
              AppConstants.currencySymbols[currencyProvider.currency] ??
              currencyProvider.currency;
          final accounts = accountProvider.accounts;

          return AlertDialog(
            title: Text(
              loan.type == LoanType.taken ? 'Pay EMI' : 'Receive EMI',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Loan: ${loan.title}'),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    prefixText: '$currencySymbol ',
                  ),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: commentsController,
                  decoration: const InputDecoration(labelText: 'Comments'),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<int>(
                  initialValue: selectedAccountId,
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: accounts
                      .map(
                        (acc) => DropdownMenuItem<int>(
                          value: acc.id,
                          child: Text(acc.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedAccountId = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text('Date: ${DateFormat.yMd().format(selectedDate)}'),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: selectedDate,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now(),
                        );
                        if (!dialogContext.mounted) return;
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: const Text('Change Date'),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final amount = double.tryParse(amountController.text);
                  if (amount == null || amount <= 0) return;

                  if (accounts.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please create an account first'),
                      ),
                    );
                    return;
                  }

                  if (selectedAccountId == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please select an account')),
                    );
                    return;
                  }

                  // 1. Create a Transaction linked to the loan
                  // This will automatically update the loan balance via TransactionProvider

                  final txProvider = Provider.of<TransactionProvider>(
                    ctx,
                    listen: false,
                  );
                  final catProvider = Provider.of<CategoryProvider>(
                    ctx,
                    listen: false,
                  );

                  final txType = loan.type == LoanType.taken
                      ? CategoryType.expense
                      : CategoryType.income;
                  final matchingCategories = catProvider.categories
                      .where((c) => c.type == txType)
                      .toList();

                  if (matchingCategories.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'No category found for this loan transaction type',
                        ),
                      ),
                    );
                    return;
                  }

                  final loanCategory = matchingCategories.firstWhere(
                    (c) => c.name == 'Loan Payment',
                    orElse: () => matchingCategories.first,
                  );

                  final newTx = Transaction(
                    title: 'EMI: ${loan.title}',
                    amount: amount,
                    date: selectedDate,
                    type: txType,
                    categoryId: loanCategory.id!,
                    notes: commentsController.text,
                    accountId: selectedAccountId,
                    loanId: loan.id, // LINK TO LOAN
                  );

                  txProvider.addTransaction(newTx);

                  // Refresh loans (TransactionProvider updates DB, but LoanProvider might need refresh)
                  // Actually TransactionProvider doesn't notify LoanProvider.
                  // But LoanProvider fetches from DB on next build if we tell it to?
                  // Or we can manually call fetchLoans()
                  Future.delayed(const Duration(milliseconds: 300), () {
                    loanProvider.fetchLoans();
                  });

                  Navigator.pop(ctx);
                },
                child: const Text('Confirm'),
              ),
            ],
          );
        },
      ),
    );
  }

class _LoanCard extends StatelessWidget {
  final Loan loan;
  final LoanType type;
  final String currencySymbol;
  final int paymentCount;
  final VoidCallback onOpen;
  final VoidCallback? onPay;
  final VoidCallback onDelete;

  const _LoanCard({
    required this.loan,
    required this.type,
    required this.currencySymbol,
    required this.paymentCount,
    required this.onOpen,
    required this.onPay,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accent = colorScheme.primary;
    final progress = loan.amount <= 0 ? 0.0 : loan.amountPaid / loan.amount;
    final remaining = (loan.amount - loan.amountPaid).clamp(0.0, loan.amount);
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();

    return Opacity(
      opacity: loan.isClosed ? 0.65 : 1,
      child: Card(
        margin: const EdgeInsets.only(bottom: 14),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
        ),
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        loan.isClosed
                            ? Icons.check_circle_outline
                            : type == LoanType.taken
                            ? Icons.south_west_rounded
                            : Icons.north_east_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loan.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'EMI $currencySymbol${loan.emiAmount.toStringAsFixed(0)} · $paymentCount logged',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!loan.isClosed)
                      _StatusPill(
                        label: 'ACTIVE',
                        color: colorScheme.secondaryContainer,
                        onColor: colorScheme.onSecondaryContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Paid $currencySymbol${loan.amountPaid.toStringAsFixed(0)}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      '$currencySymbol${remaining.toStringAsFixed(0)} left',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: clampedProgress,
                    minHeight: 8,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(accent),
                  ),
                ),
                if (!loan.isClosed) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        '${(clampedProgress * 100).toStringAsFixed(0)}% paid',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      if (onPay != null)
                        TextButton(
                          onPressed: onPay,
                          child: Text(
                            type == LoanType.taken ? 'Pay EMI' : 'Receive EMI',
                          ),
                        ),
                      IconButton(
                        tooltip: 'Delete loan',
                        icon: const Icon(Icons.delete_outline_rounded),
                        color: colorScheme.onSurfaceVariant,
                        onPressed: onDelete,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color onColor;

  const _StatusPill({
    required this.label,
    required this.color,
    required this.onColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: onColor,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
