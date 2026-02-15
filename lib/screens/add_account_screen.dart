import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/account.dart';
import '../providers/account_provider.dart';

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

      final provider = Provider.of<AccountProvider>(context, listen: false);

      if (widget.account != null) {
        // Edit
        final updatedAccount = Account(
          id: widget.account!.id,
          name: _name,
          type: _type,
          balance:
              _initialBalance, // Note: Editing balance directly might be risky if transactions exist, but for now simple edit.
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
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.account == null ? 'Add Account' : 'Edit Account'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
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
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitData,
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
