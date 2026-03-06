import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/loan.dart';

import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/account_provider.dart';
import '../providers/loan_provider.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;

  const AddTransactionScreen({super.key, this.transaction});

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _title;
  late double _amount;
  late DateTime _selectedDate;
  late CategoryType _type;
  Category? _selectedCategory;
  late bool _isForeignCurrency;
  double? _originalAmount;
  String? _originalCurrency;
  int? _selectedAccountId;
  int? _transferAccountId;
  int? _selectedLoanId;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      if (widget.transaction != null) {
        _title = widget.transaction!.title;
        _amount = widget.transaction!.amount;
        _selectedDate = widget.transaction!.date;
        _type = widget.transaction!.type;
        _selectedAccountId = widget.transaction!.accountId;
        _transferAccountId = widget.transaction!.transferAccountId;
        _selectedLoanId = widget.transaction!.loanId;
        _isForeignCurrency = widget.transaction!.originalAmount != null;
        _originalAmount = widget.transaction!.originalAmount;
        _originalCurrency = widget.transaction!.originalCurrency ?? 'USD';

        final categories = Provider.of<CategoryProvider>(
          context,
          listen: false,
        ).categories;
        try {
          _selectedCategory = categories.firstWhere(
            (c) => c.id == widget.transaction!.categoryId,
          );
        } catch (e) {
          _selectedCategory = null; // Category might have been deleted
        }
      } else {
        _title = '';
        _amount = 0.0;
        _selectedDate = DateTime.now();
        _type = CategoryType.expense;
        _isForeignCurrency = false;
        _originalCurrency = 'USD';
      }
      _isInit = false;
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      int categoryId;
      if (_type == CategoryType.transfer) {
        // Find Transfer category
        final categories = Provider.of<CategoryProvider>(
          context,
          listen: false,
        ).categories;
        try {
          categoryId = categories
              .firstWhere((c) => c.type == CategoryType.transfer)
              .id!;
        } catch (e) {
          // Fallback if no transfer category exists (shouldn't happen with initCategories)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: Transfer category not found')),
          );
          return;
        }

        if (_transferAccountId == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select destination account')),
          );
          return;
        }
      } else {
        if (_selectedCategory == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please select a category')),
          );
          return;
        }
        categoryId = _selectedCategory!.id!;
      }

      final txProvider = Provider.of<TransactionProvider>(
        context,
        listen: false,
      );
      final accProvider = Provider.of<AccountProvider>(context, listen: false);

      if (widget.transaction != null) {
        // Update existing transaction
        final updatedTx = Transaction(
          id: widget.transaction!.id,
          title: _title,
          amount: _amount,
          date: _selectedDate,
          type: _type,
          categoryId: categoryId,
          accountId: _selectedAccountId,
          transferAccountId: _type == CategoryType.transfer
              ? _transferAccountId
              : null,
          loanId: _selectedLoanId,
          originalAmount: _isForeignCurrency ? _originalAmount : null,
          originalCurrency: _isForeignCurrency ? _originalCurrency : null,
        );
        txProvider.updateTransaction(updatedTx);
      } else {
        // Add new transaction
        final newTx = Transaction(
          title: _title,
          amount: _amount,
          date: _selectedDate,
          type: _type,
          categoryId: categoryId,
          accountId: _selectedAccountId,
          transferAccountId: _type == CategoryType.transfer
              ? _transferAccountId
              : null,
          loanId: _selectedLoanId,
          originalAmount: _isForeignCurrency ? _originalAmount : null,
          originalCurrency: _isForeignCurrency ? _originalCurrency : null,
        );
        txProvider.addTransaction(newTx);
      }

      // Refresh accounts to show updated balance
      Future.delayed(Duration.zero, () {
        accProvider.fetchAccounts();
      });

      Navigator.of(context).pop();
    }
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _selectedDate = pickedDate;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Filter categories based on selected type
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categories = categoryProvider.categories
        .where((c) => c.type == _type)
        .toList();

    // Reset selected category if it doesn't match type (only if not editing or type changed manually)
    // We need to be careful not to unset it if we just loaded it from transaction
    if (_selectedCategory != null && _selectedCategory!.type != _type) {
      _selectedCategory = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction != null ? 'Edit Transaction' : 'Add Transaction',
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Custom Segmented Control for Transaction Type
              Container(
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTypeSegment(
                      'Expense',
                      CategoryType.expense,
                      Theme.of(context).colorScheme.error,
                    ),
                    _buildTypeSegment(
                      'Income',
                      CategoryType.income,
                      Theme.of(context).colorScheme.tertiary,
                    ),
                    _buildTypeSegment(
                      'Transfer',
                      CategoryType.transfer,
                      Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
              // Basic Details Card
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Transaction Details',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _title,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.edit_outlined),
                        ),
                        validator: (val) {
                          if (val == null || val.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                        onSaved: (val) {
                          _title = val!;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _amount > 0 ? _amount.toString() : null,
                        decoration: InputDecoration(
                          labelText: _isForeignCurrency
                              ? 'Amount in Default Currency (Equivalent)'
                              : 'Amount',
                          prefixIcon: const Icon(Icons.currency_exchange_outlined),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (val == null || double.tryParse(val) == null) {
                            return 'Please enter a valid amount';
                          }
                          return null;
                        },
                        onSaved: (val) {
                          _amount = double.parse(val!);
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Date',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: _presentDatePicker,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_outlined,
                                          size: 18,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          DateFormat.yMd().format(_selectedDate),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Consumer<AccountProvider>(
                builder: (context, accProvider, child) {
                  if (_type == CategoryType.transfer) {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.compare_arrows_rounded,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Transfer Between Accounts',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'From Account',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                              ),
                              initialValue: _selectedAccountId,
                              validator: (val) {
                                if (val == null) {
                                  return 'Select source account';
                                }
                                return null;
                              },
                              items: accProvider.accounts.map((acc) {
                                return DropdownMenuItem<int>(
                                  value: acc.id,
                                  child: Text(
                                    '${acc.name} - ${_getCurrencySymbol('INR')}${acc.balance.toStringAsFixed(2)}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _selectedAccountId = val;
                                });
                              },
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.blue,
                                size: 28,
                              ),
                            ),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'To Account',
                                prefixIcon: Icon(Icons.savings_outlined),
                              ),
                              initialValue: _transferAccountId,
                              validator: (val) {
                                if (val == null) {
                                  return 'Select destination account';
                                }
                                if (val == _selectedAccountId) {
                                  return 'Cannot transfer to same account';
                                }
                                return null;
                              },
                              items: accProvider.accounts.map((acc) {
                                return DropdownMenuItem<int>(
                                  value: acc.id,
                                  child: Text(
                                    '${acc.name} - ${_getCurrencySymbol('INR')}${acc.balance.toStringAsFixed(2)}',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setState(() {
                                  _transferAccountId = val;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            labelText: 'Account',
                            prefixIcon:
                                Icon(Icons.account_balance_wallet_outlined),
                          ),
                          initialValue: _selectedAccountId,
                          validator: (val) {
                            if (val == null) {
                              return 'Please select an account';
                            }
                            return null;
                          },
                          items: accProvider.accounts.map((acc) {
                            return DropdownMenuItem<int>(
                              value: acc.id,
                              child: Text(
                                '${acc.name} - ${_getCurrencySymbol('INR')}${acc.balance.toStringAsFixed(2)}',
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedAccountId = val;
                            });
                          },
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
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
                            'Currency Details',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          FilterChip(
                            label: const Text('Foreign Currency?'),
                            selected: _isForeignCurrency,
                            onSelected: (val) {
                              setState(() {
                                _isForeignCurrency = val;
                              });
                            },
                            showCheckmark: false,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isForeignCurrency) ...[
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue:
                                    _originalAmount?.toString(),
                                decoration: const InputDecoration(
                                  labelText: 'Amount (Foreign)',
                                  prefixIcon:
                                      Icon(Icons.currency_exchange_outlined),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (_isForeignCurrency &&
                                      (val == null ||
                                          double.tryParse(val) == null)) {
                                    return 'Enter valid amount';
                                  }
                                  return null;
                                },
                                onSaved: (val) {
                                  if (_isForeignCurrency) {
                                    _originalAmount =
                                        double.parse(val!);
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 1,
                              child:
                                  DropdownButtonFormField<String>(
                                decoration: const InputDecoration(
                                  labelText: 'Currency',
                                ),
                                initialValue: _originalCurrency,
                                items: [
                                  'USD',
                                  'EUR',
                                  'GBP',
                                  'INR'
                                ]
                                    .map(
                                      (c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) => setState(
                                  () =>
                                      _originalCurrency = val!,
                                ),
                                onSaved: (val) {
                                  if (_isForeignCurrency) {
                                    _originalCurrency = val!;
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_type != CategoryType.transfer)
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      width: 0.5,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Category',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Category>(
                          decoration: const InputDecoration(
                            labelText: 'Select Category',
                            prefixIcon:
                                Icon(Icons.category_outlined),
                          ),
                          initialValue: _selectedCategory,
                          items: categories.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Color(cat.colorValue)
                                          .withOpacity(0.15),
                                      borderRadius:
                                          BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      IconData(
                                        cat.iconCode,
                                        fontFamily: cat.fontFamily ??
                                            'MaterialIcons',
                                        fontPackage: cat.fontPackage,
                                      ),
                                      size: 14,
                                      color: Color(cat.colorValue),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(cat.name),
                                ],
                              ),
                            );
                          }).toList(),
                          validator: (val) {
                            if (_type != CategoryType.transfer &&
                                val == null) {
                              return 'Please select a category';
                            }
                            return null;
                          },
                          onChanged: (val) {
                            setState(() {
                              _selectedCategory = val;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              if (_type != CategoryType.transfer)
                const SizedBox(height: 16),
              Consumer<LoanProvider>(
                builder: (context, loanProvider, child) {
                  // Only taken/given relevant to txn type?
                  // Let's list all open loans.
                  // Or filter: If Expense -> Paying Loan (Taken) or Giving Loan (Given).
                  // If Income -> Receiving Loan (Given) or Getting Loan (Taken).
                  // For simplicity, list all open loans for now.

                  final loans = loanProvider.loans
                      .where((l) => !l.isClosed)
                      .toList();

                  if (loans.isEmpty) return const SizedBox.shrink();

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                        width: 0.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Linked Loan (Optional)',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Link this transaction to an open loan',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int>(
                            decoration: const InputDecoration(
                              labelText: 'Select Loan',
                              prefixIcon: Icon(Icons.credit_score_outlined),
                            ),
                            initialValue: _selectedLoanId,
                            items: [
                              const DropdownMenuItem<int>(
                                value: null,
                                child: Text('None'),
                              ),
                              ...loans.map((loan) {
                                return DropdownMenuItem<int>(
                                  value: loan.id,
                                  child: Text(
                                    '${loan.title} (${loan.type == LoanType.taken ? 'Taken' : 'Given'})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() {
                                _selectedLoanId = val;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _submitData,
                child: Text(
                  widget.transaction != null
                      ? 'Update Transaction'
                      : 'Add Transaction',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment(
    String title,
    CategoryType type,
    Color color,
  ) {
    bool isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = type;
            // Reset category if switching type (unless editing same txn)
            if (_selectedCategory != null &&
                _selectedCategory!.type != type) {
              _selectedCategory = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: !isSelected
                ? Border.all(
                    color: color.withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : color.withOpacity(0.7),
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
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
}
