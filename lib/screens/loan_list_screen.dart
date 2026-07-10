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
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Loans'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Taken'),
              Tab(text: 'Given'),
            ],
          ),
        ),
        bottomNavigationBar: const AppBottomNav(currentRoute: '/loans'),
        body: const TabBarView(
          children: [
            LoanList(type: LoanType.taken),
            LoanList(type: LoanType.given),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).pushNamed('/add-loan');
          },
          child: const Icon(Icons.add),
        ),
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
                  : () => _showPaymentDialog(context, loan, provider),
              onDelete: () => provider.deleteLoan(loan.id!),
            );
          },
        );
      },
    );
  }

  void _showPaymentDialog(
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
    final accent = type == LoanType.taken ? Colors.deepOrange : Colors.teal;
    final progress = loan.amount <= 0 ? 0.0 : loan.amountPaid / loan.amount;
    final remaining = (loan.amount - loan.amountPaid).clamp(0.0, loan.amount);
    final clampedProgress = progress.clamp(0.0, 1.0).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: accent.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: accent.withValues(alpha: 0.18)),
      ),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: accent.withValues(alpha: 0.14),
                    child: Icon(
                      type == LoanType.taken
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: accent,
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
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          '$paymentCount EMI${paymentCount == 1 ? '' : 's'} logged',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _StatusPill(
                    label: loan.isClosed ? 'Closed' : 'Active',
                    color: loan.isClosed ? Colors.green : accent,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                '$currencySymbol${remaining.toStringAsFixed(0)} left',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'of $currencySymbol${loan.amount.toStringAsFixed(0)} • EMI $currencySymbol${loan.emiAmount.toStringAsFixed(2)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: clampedProgress,
                  minHeight: 10,
                  backgroundColor: Colors.white,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: 10),
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
                    color: Colors.grey.shade600,
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
