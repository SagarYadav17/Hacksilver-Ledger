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
import '../utils/security_utils.dart';
import '../utils/icon_utils.dart';
import '../utils/amount_colors.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  final CategoryType? initialType;
  final Transaction? duplicateFrom;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.initialType,
    this.duplicateFrom,
  });

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
      } else if (widget.duplicateFrom != null) {
        final source = widget.duplicateFrom!;
        _title = source.title;
        _amount = source.amount;
        _selectedDate = DateTime.now();
        _type = source.type;
        _selectedAccountId = source.accountId;
        _transferAccountId = source.transferAccountId;
        _selectedLoanId = source.loanId;
        _isForeignCurrency = source.originalAmount != null;
        _originalAmount = source.originalAmount;
        _originalCurrency = source.originalCurrency ?? 'USD';

        final categories = Provider.of<CategoryProvider>(
          context,
          listen: false,
        ).categories;
        try {
          _selectedCategory = categories.firstWhere(
            (c) => c.id == source.categoryId,
          );
        } catch (e) {
          _selectedCategory = null;
        }
      } else {
        _title = '';
        _amount = 0.0;
        _selectedDate = DateTime.now();
        _type = widget.initialType ?? CategoryType.expense;
        _isForeignCurrency = false;
        _originalCurrency = 'USD';
      }
      _isInit = false;
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validate title securely
      final titleValidation = SecurityUtils.validateTitle(_title);
      if (!titleValidation.isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(titleValidation.errorMessage!)));
        return;
      }
      _title = titleValidation.value;

      // Validate amount securely
      final amountValidation = SecurityUtils.validateAmount(
        _amount.toString(),
        maxValue: 999999999.99,
      );
      if (!amountValidation.isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(amountValidation.errorMessage!)));
        return;
      }
      _amount = amountValidation.value;

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

      int? validatedLoanId = _selectedLoanId;
      if (_type == CategoryType.transfer) {
        validatedLoanId = null;
      }

      if (validatedLoanId != null) {
        final loans = Provider.of<LoanProvider>(context, listen: false).loans;
        try {
          final linkedLoan = loans.firstWhere((l) => l.id == validatedLoanId);
          final isValidLoanLink =
              (_type == CategoryType.expense &&
                  linkedLoan.type == LoanType.taken) ||
              (_type == CategoryType.income &&
                  linkedLoan.type == LoanType.given);

          if (!isValidLoanLink) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Invalid loan link. Use Expense for Taken loans and Income for Given loans.',
                ),
              ),
            );
            return;
          }
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Selected loan was not found')),
          );
          return;
        }
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
          loanId: validatedLoanId,
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
          loanId: validatedLoanId,
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
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = amountColorForType(colorScheme, _type);
    // Filter categories based on selected type
    final categoryProvider = Provider.of<CategoryProvider>(context);
    final categories = categoryProvider.categories
        .where((c) => c.type == _type && !c.isArchived)
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
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SegmentedButton<CategoryType>(
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? typeColor.withValues(alpha: 0.14)
                            : null,
                      ),
                      foregroundColor: WidgetStateProperty.resolveWith(
                        (states) => states.contains(WidgetState.selected)
                            ? typeColor
                            : null,
                      ),
                      side: WidgetStatePropertyAll(
                        BorderSide(color: colorScheme.outlineVariant),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: CategoryType.expense,
                        label: Text('Expense'),
                      ),
                      ButtonSegment(
                        value: CategoryType.income,
                        label: Text('Income'),
                      ),
                      ButtonSegment(
                        value: CategoryType.transfer,
                        label: Text('Transfer'),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (selection) {
                      setState(() {
                        _type = selection.first;
                        _selectedLoanId = null;
                        if (_selectedCategory != null &&
                            _selectedCategory!.type != _type) {
                          _selectedCategory = null;
                        }
                      });
                    },
                  ),
                ),
                if (widget.transaction == null && widget.duplicateFrom == null)
                  _RecentTemplateChips(
                    type: _type,
                    categories: Provider.of<CategoryProvider>(
                      context,
                      listen: false,
                    ).categories,
                    onSelected: (template) {
                      setState(() {
                        _type = template.type;
                        _title = template.title;
                        _amount = template.amount;
                        _selectedAccountId = template.accountId;
                        _transferAccountId = template.transferAccountId;
                        _selectedLoanId = null;
                        if (template.type != CategoryType.transfer) {
                          _selectedCategory = template.category;
                        }
                      });
                    },
                  ),
                // Amount-first fast entry card
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
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
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                _type == CategoryType.income
                                    ? Icons.south_west_rounded
                                    : _type == CategoryType.expense
                                    ? Icons.north_east_rounded
                                    : Icons.swap_horiz_rounded,
                                size: 18,
                                color: typeColor,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              _type == CategoryType.transfer
                                  ? 'Transfer amount'
                                  : 'Amount',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (_isForeignCurrency)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              'Amount in default currency (equivalent)',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ),
                        TextFormField(
                          key: ValueKey('amount-$_amount'),
                          initialValue: _amount > 0 ? _amount.toString() : null,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                              ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            filled: false,
                            hintText: '0',
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
                        TextFormField(
                          key: ValueKey('title-$_title'),
                          initialValue: _title,
                          decoration: const InputDecoration(
                            labelText: 'Note',
                            prefixIcon: Icon(Icons.edit_outlined),
                          ),
                          validator: (val) {
                            if (val == null || val.isEmpty) {
                              return 'Please enter a note';
                            }
                            return null;
                          },
                          onSaved: (val) {
                            _title = val!;
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
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelLarge,
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
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.outlineVariant,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today_outlined,
                                            size: 18,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            DateFormat.yMd().format(
                                              _selectedDate,
                                            ),
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
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
                        color: groupingColor(
                          colorScheme,
                        ).withValues(alpha: 0.07),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: groupingColor(
                              colorScheme,
                            ).withValues(alpha: 0.3),
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
                                      color: groupingColor(
                                        colorScheme,
                                      ).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.compare_arrows_rounded,
                                      color: groupingColor(colorScheme),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Transfer Between Accounts',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                                child: Icon(
                                  Icons.arrow_downward_rounded,
                                  color: groupingColor(colorScheme),
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
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
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
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
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
                                  initialValue: _originalAmount?.toString(),
                                  decoration: const InputDecoration(
                                    labelText: 'Amount (Foreign)',
                                    prefixIcon: Icon(
                                      Icons.currency_exchange_outlined,
                                    ),
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
                                      _originalAmount = double.parse(val!);
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String>(
                                  decoration: const InputDecoration(
                                    labelText: 'Currency',
                                  ),
                                  initialValue: _originalCurrency,
                                  items: ['USD', 'EUR', 'GBP', 'INR']
                                      .map(
                                        (c) => DropdownMenuItem(
                                          value: c,
                                          child: Text(c),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (val) =>
                                      setState(() => _originalCurrency = val!),
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
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (categories.isEmpty)
                            Text(
                              'No categories found for this type',
                              style: Theme.of(context).textTheme.bodyMedium,
                            )
                          else
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 4,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 0.85,
                                  ),
                              itemCount: categories.length,
                              itemBuilder: (context, index) {
                                final cat = categories[index];
                                final selected =
                                    _selectedCategory?.id == cat.id;
                                final catColor = Color(cat.colorValue);
                                return InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    setState(() {
                                      _selectedCategory = cat;
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? catColor.withValues(alpha: 0.18)
                                          : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(16),
                                      border: selected
                                          ? Border.all(
                                              color: catColor,
                                              width: 2,
                                            )
                                          : null,
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          categoryIconData(
                                            cat.iconCode,
                                            fontFamily: cat.fontFamily,
                                            fontPackage: cat.fontPackage,
                                          ),
                                          color: catColor,
                                          size: 22,
                                        ),
                                        const SizedBox(height: 6),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                          ),
                                          child: Text(
                                            cat.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.labelSmall,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          if (_selectedCategory == null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'Choose a category before saving',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                    ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (_type != CategoryType.transfer) const SizedBox(height: 16),
                if (_type != CategoryType.transfer)
                  Consumer<LoanProvider>(
                    builder: (context, loanProvider, child) {
                      final loans = loanProvider.loans
                          .where(
                            (l) =>
                                !l.isClosed &&
                                ((_type == CategoryType.expense &&
                                        l.type == LoanType.taken) ||
                                    (_type == CategoryType.income &&
                                        l.type == LoanType.given)),
                          )
                          .toList();

                      if (loans.isEmpty) return const SizedBox.shrink();

                      final dropdownValue =
                          loans.any((l) => l.id == _selectedLoanId)
                          ? _selectedLoanId
                          : null;

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
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Only repayment-compatible open loans are shown',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<int>(
                                decoration: const InputDecoration(
                                  labelText: 'Select Loan',
                                  prefixIcon: Icon(Icons.credit_score_outlined),
                                ),
                                initialValue: dropdownValue,
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
                    backgroundColor: typeColor,
                    foregroundColor: colorScheme.onPrimary,
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

class _RecentTemplateChips extends StatelessWidget {
  final CategoryType type;
  final List<Category> categories;
  final ValueChanged<_TransactionTemplate> onSelected;

  const _RecentTemplateChips({
    required this.type,
    required this.categories,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final transactions = context.watch<TransactionProvider>().transactions;
    final templates = <_TransactionTemplate>[];
    final seen = <String>{};

    for (final tx in transactions) {
      if (tx.type != type) continue;
      final category = categories.firstWhere(
        (cat) => cat.id == tx.categoryId,
        orElse: () => Category(
          name: 'Unknown',
          iconCode: Icons.help_outline.codePoint,
          colorValue: Colors.grey.toARGB32(),
          type: tx.type,
          isCustom: false,
        ),
      );
      final key = '${tx.type}-${tx.title}-${tx.categoryId}-${tx.amount}';
      if (!seen.add(key)) continue;

      templates.add(
        _TransactionTemplate(
          title: tx.title,
          amount: tx.amount,
          type: tx.type,
          category: category,
          accountId: tx.accountId,
          transferAccountId: tx.transferAccountId,
        ),
      );
      if (templates.length == 5) break;
    }

    if (templates.isEmpty) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent & templates',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final template in templates)
                  ActionChip(
                    avatar: Icon(
                      categoryIconData(
                        template.category.iconCode,
                        fontFamily: template.category.fontFamily,
                        fontPackage: template.category.fontPackage,
                      ),
                      size: 18,
                      color: Color(template.category.colorValue),
                    ),
                    label: Text(
                      '${template.title} ${template.amount.toStringAsFixed(0)}',
                    ),
                    onPressed: () => onSelected(template),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTemplate {
  final String title;
  final double amount;
  final CategoryType type;
  final Category category;
  final int? accountId;
  final int? transferAccountId;

  const _TransactionTemplate({
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    this.accountId,
    this.transferAccountId,
  });
}
