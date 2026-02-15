import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../models/category.dart';
import '../providers/loan_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import 'add_transaction_screen.dart';

class LoanDetailsScreen extends StatelessWidget {
  final int loanId;

  const LoanDetailsScreen({super.key, required this.loanId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Loan Details')),
      body: Consumer2<LoanProvider, TransactionProvider>(
        builder: (context, loanProvider, txProvider, child) {
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

          // Sort by date descending
          linkedTransactions.sort((a, b) => b.date.compareTo(a.date));

          final progress = loan.amountPaid / loan.amount;

          return Column(
            children: [
              // Loan Summary Card
              Card(
                margin: const EdgeInsets.all(16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: loan.isClosed
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              loan.isClosed ? 'CLOSED' : 'ACTIVE',
                              style: TextStyle(
                                color: loan.isClosed
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildsummaryItem(
                            'Amount',
                            loan.amount.toStringAsFixed(0),
                          ),
                          _buildsummaryItem(
                            'Paid',
                            loan.amountPaid.toStringAsFixed(0),
                            color: Colors.green,
                          ),
                          _buildsummaryItem(
                            'Remaining',
                            (loan.amount - loan.amountPaid).toStringAsFixed(0),
                            color: Colors.red,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          loan.type == LoanType.taken
                              ? Colors.red
                              : Colors.green,
                        ),
                        minHeight: 10,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(progress * 100).toStringAsFixed(1)}% Paid',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
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
                                  colorValue: Colors.grey.value,
                                  type: CategoryType.expense,
                                  isCustom: false,
                                ),
                              );

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(
                                category.colorValue,
                              ).withOpacity(0.2),
                              child: Icon(
                                IconData(
                                  category.iconCode,
                                  fontFamily:
                                      category.fontFamily ?? 'MaterialIcons',
                                  fontPackage: category.fontPackage,
                                ),
                                color: Color(category.colorValue),
                              ),
                            ),
                            title: Text(tx.title),
                            subtitle: Text(DateFormat.yMMMd().format(tx.date)),
                            trailing: Text(
                              tx.amount.toStringAsFixed(2),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: tx.type == CategoryType.income
                                    ? Colors.green
                                    : tx.type == CategoryType.expense
                                    ? Colors.red
                                    : Colors.blue,
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

  Widget _buildsummaryItem(String label, String value, {Color? color}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
