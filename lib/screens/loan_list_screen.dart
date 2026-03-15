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
import '../widgets/custom_drawer.dart';
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
        drawer: const CustomDrawer(currentRoute: '/loans'),
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
    return Consumer2<LoanProvider, CurrencyProvider>(
      builder: (context, provider, currencyProvider, child) {
        final currencySymbol =
            AppConstants.currencySymbols[currencyProvider.currency] ??
            currencyProvider.currency;
        final loans = provider.loans.where((l) => l.type == type).toList();

        if (loans.isEmpty) {
          return const Center(child: Text('No loans found.'));
        }

        return ListView.builder(
          itemCount: loans.length,
          itemBuilder: (context, index) {
            final loan = loans[index];
            final progress = loan.amountPaid / loan.amount;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              clipBehavior: Clip.antiAlias, // For InkWell ripple
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => LoanDetailsScreen(loanId: loan.id!),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            loan.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                          if (loan.isClosed)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'CLOSED',
                                style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Amount: $currencySymbol${loan.amount.toStringAsFixed(0)}',
                          ),
                          Text(
                            'EMI: $currencySymbol${loan.emiAmount.toStringAsFixed(2)}',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          type == LoanType.taken ? Colors.red : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Paid: $currencySymbol${loan.amountPaid.toStringAsFixed(0)} / $currencySymbol${loan.amount.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (!loan.isClosed)
                            TextButton(
                              onPressed: () {
                                _showPaymentDialog(context, loan, provider);
                              },
                              child: Text(
                                type == LoanType.taken
                                    ? 'PAY EMI'
                                    : 'RECEIVE EMI',
                              ),
                            ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outlined,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              provider.deleteLoan(loan.id!);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
