import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';
import '../utils/security_utils.dart';
import '../utils/amount_colors.dart';

class AddAccountScreen extends StatefulWidget {
  final Account? account;

  const AddAccountScreen({super.key, this.account});

  @override
  State<AddAccountScreen> createState() => _AddAccountScreenState();
}

class _AddAccountScreenState extends State<AddAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  late String _name;
  late AccountType _type;
  late double _initialBalance;

  @override
  void initState() {
    super.initState();
    if (widget.account != null) {
      _name = widget.account!.name;
      _type = widget.account!.type;
      _initialBalance = widget.account!.balance;
    } else {
      _name = '';
      _type = AccountType.bank;
      _initialBalance = 0.0;
    }
  }

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      // Validate account name
      final nameValidation = SecurityUtils.validateTitle(_name, maxLength: 50);
      if (!nameValidation.isValid) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(nameValidation.errorMessage!)));
        return;
      }
      _name = nameValidation.value;

      // Validate initial balance
      final balanceValidation = SecurityUtils.validateAmount(
        _initialBalance.toString(),
        allowNegative: true,
        minValue: -999999999.99,
        maxValue: 999999999.99,
      );
      if (!balanceValidation.isValid) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(balanceValidation.errorMessage!)),
        );
        return;
      }
      _initialBalance = balanceValidation.value;

      final provider = Provider.of<AccountProvider>(context, listen: false);

      if (widget.account != null) {
        // Edit
        final updatedAccount = Account(
          id: widget.account!.id,
          name: _name,
          type: _type,
          balance: _initialBalance,
        );
        provider.updateAccount(updatedAccount);
      } else {
        // Add
        final newAccount = Account(
          name: _name,
          type: _type,
          balance: _initialBalance,
        );
        provider.addAccount(newAccount);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: groupingColor(colorScheme).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance_wallet_outlined,
                      color: groupingColor(colorScheme),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.account == null
                            ? 'Create a place for cash, bank money, or a card.'
                            : 'Update this account without changing its transactions.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              TextFormField(
                initialValue: _name,
                decoration: const InputDecoration(labelText: 'Account Name'),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
                onSaved: (val) {
                  _name = val!;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<AccountType>(
                initialValue: _type,
                items: AccountType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(
                          type.toString().split('.').last.toUpperCase(),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _type = val!;
                  });
                },
                decoration: const InputDecoration(labelText: 'Account Type'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                initialValue: _initialBalance.toString(),
                decoration: const InputDecoration(labelText: 'Initial Balance'),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || double.tryParse(val) == null) {
                    return 'Please enter a valid amount';
                  }
                  return null;
                },
                onSaved: (val) {
                  _initialBalance = double.parse(val!);
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _submitData,
                style: FilledButton.styleFrom(
                  backgroundColor: groupingColor(colorScheme),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  widget.account == null ? 'Add Account' : 'Update Account',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
