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
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    _buildTypeSegment(
                      'Expense',
                      CategoryType.expense,
                      Colors.red,
                    ),
                    _buildTypeSegment(
                      'Income',
                      CategoryType.income,
                      Colors.green,
                    ),
                    _buildTypeSegment(
                      'Transfer',
                      CategoryType.transfer,
                      Colors.blue,
                    ),
                  ],
                ),
              ),
              TextFormField(
                initialValue: _title,
                decoration: const InputDecoration(labelText: 'Title'),
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
              Consumer<AccountProvider>(
                builder: (context, accProvider, child) {
                  if (_type == CategoryType.transfer) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.blueAccent),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Transfer Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'From Account',
                                prefixIcon: Icon(
                                  Icons.account_balance_wallet_outlined,
                                ),
                                border: OutlineInputBorder(),
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
                                    '${acc.name} (₹${acc.balance.toStringAsFixed(2)})',
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
                              padding: EdgeInsets.symmetric(vertical: 8.0),
                              child: Icon(
                                Icons.arrow_downward_rounded,
                                color: Colors.blue,
                                size: 32,
                              ),
                            ),
                            DropdownButtonFormField<int>(
                              decoration: const InputDecoration(
                                labelText: 'To Account',
                                prefixIcon: Icon(Icons.savings_outlined),
                                border: OutlineInputBorder(),
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
                                    '${acc.name} (₹${acc.balance.toStringAsFixed(2)})',
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
                    return DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Account',
                        prefixIcon: Icon(Icons.account_balance_wallet_outlined),
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
                            '${acc.name} (₹${acc.balance.toStringAsFixed(2)})',
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedAccountId = val;
                        });
                      },
                    );
                  }
                },
              ),
              SwitchListTile(
                title: const Text('Foreign Currency?'),
                value: _isForeignCurrency,
                onChanged: (val) {
                  setState(() {
                    _isForeignCurrency = val;
                  });
                },
              ),
              if (_isForeignCurrency) ...[
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: _originalAmount?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Amount (Foreign)',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (val) {
                          if (_isForeignCurrency &&
                              (val == null || double.tryParse(val) == null)) {
                            return 'Enter valid amount';
                          }
                          return null;
                        },
                        onSaved: (val) {
                          if (_isForeignCurrency) {
                            _originalAmount = double.parse(val!);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Currency',
                        ),
                        initialValue: _originalCurrency,
                        items: ['USD', 'EUR', 'GBP', 'INR']
                            .map(
                              (c) => DropdownMenuItem(value: c, child: Text(c)),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _originalCurrency = val!),
                        onSaved: (val) {
                          if (_isForeignCurrency) _originalCurrency = val!;
                        },
                      ),
                    ),
                  ],
                ),
              ],
              TextFormField(
                initialValue: _amount > 0
                    ? _amount.toString()
                    : null, // Prevent 0.0 showing on new add
                decoration: InputDecoration(
                  labelText: _isForeignCurrency
                      ? 'Amount in Default Currency (Equivalent)'
                      : 'Amount',
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Date: ${DateFormat.yMd().format(_selectedDate)}',
                    ),
                  ),
                  TextButton(
                    onPressed: _presentDatePicker,
                    child: const Text('Choose Date'),
                  ),
                ],
              ),
              DropdownButtonFormField<Category>(
                decoration: const InputDecoration(labelText: 'Category *'),
                initialValue: _selectedCategory,
                items: categories.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Row(
                      children: [
                        Icon(
                          IconData(
                            cat.iconCode,
                            fontFamily: cat.fontFamily ?? 'MaterialIcons',
                            fontPackage: cat.fontPackage,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(cat.name),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCategory = val;
                  });
                },
              ),
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

                  return DropdownButtonFormField<int>(
                    decoration: const InputDecoration(
                      labelText: 'Link to Loan (Optional)',
                      helperText:
                          'Select a loan if this transaction is related to one',
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
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitData,
                child: Text(
                  widget.transaction != null
                      ? 'Update Transaction'
                      : 'Add Transaction',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSegment(String title, CategoryType type, Color color) {
    bool isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _type = type;
            // Reset category if switching type (unless editing same txn)
            if (_selectedCategory != null && _selectedCategory!.type != type) {
              _selectedCategory = null;
            }
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
