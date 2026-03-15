import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../providers/loan_provider.dart';
import '../providers/currency_provider.dart';
import '../constants/app_constants.dart';

class AddLoanScreen extends StatefulWidget {
  final Loan? loan;

  const AddLoanScreen({super.key, this.loan});

  @override
  State<AddLoanScreen> createState() => _AddLoanScreenState();
}

class _AddLoanScreenState extends State<AddLoanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  final _tenureController = TextEditingController();
  final _notesController = TextEditingController();

  LoanType _type = LoanType.taken;
  DateTime _startDate = DateTime.now();
  double _calculatedEMI = 0.0;
  bool _isInit = true;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateEMI);
    _rateController.addListener(_updateEMI);
    _tenureController.addListener(_updateEMI);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final loan = widget.loan;
      if (loan != null) {
        _titleController.text = loan.title;
        _amountController.text = loan.amount.toStringAsFixed(2);
        _rateController.text = loan.interestRate.toStringAsFixed(2);
        _tenureController.text = loan.tenureMonths.toString();
        _notesController.text = loan.notes ?? '';
        _type = loan.type;
        _startDate = loan.startDate;
        _calculatedEMI = loan.emiAmount;
      }
      _isInit = false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _tenureController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _updateEMI() {
    final amount = double.tryParse(_amountController.text) ?? 0;
    final rate = double.tryParse(_rateController.text) ?? 0;
    final tenure = int.tryParse(_tenureController.text) ?? 0;

    if (amount > 0 && tenure > 0) {
      setState(() {
        _calculatedEMI = Loan.calculateEMI(amount, rate, tenure);
      });
    } else {
      setState(() {
        _calculatedEMI = 0.0;
      });
    }
  }

  Future<void> _submitData() async {
    if (_formKey.currentState!.validate()) {
      final provider = Provider.of<LoanProvider>(context, listen: false);
      final editingLoan = widget.loan;

      final loan = Loan(
        id: editingLoan?.id,
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        interestRate: double.parse(_rateController.text),
        tenureMonths: int.parse(_tenureController.text),
        type: _type,
        startDate: _startDate,
        emiAmount: _calculatedEMI,
        amountPaid: editingLoan?.amountPaid ?? 0.0,
        isClosed: editingLoan?.isClosed ?? false,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      if (editingLoan == null) {
        await provider.addLoan(loan);
      } else {
        await provider.updateLoan(loan);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    }
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _startDate = pickedDate;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final currencyCode = context.watch<CurrencyProvider>().currency;
    final currencySymbol =
        AppConstants.currencySymbols[currencyCode] ?? currencyCode;
    final isEditing = widget.loan != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit Loan' : 'Add Loan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Type Selection
              RadioGroup<LoanType>(
                groupValue: _type,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _type = value);
                  }
                },
                child: Row(
                  children: [
                    Expanded(
                      child: RadioListTile<LoanType>(
                        title: const Text('Loan Taken'),
                        value: LoanType.taken,
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<LoanType>(
                        title: const Text('Loan Given'),
                        value: LoanType.given,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g. Home Loan)',
                ),
                validator: (val) => val!.isEmpty ? 'Enter a title' : null,
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      decoration: const InputDecoration(labelText: 'Amount'),
                      keyboardType: TextInputType.number,
                      validator: (val) => double.tryParse(val!) == null
                          ? 'Invalid amount'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _rateController,
                      decoration: const InputDecoration(
                        labelText: 'Interest Rate (%)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (val) =>
                          double.tryParse(val!) == null ? 'Invalid rate' : null,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _tenureController,
                decoration: const InputDecoration(labelText: 'Tenure (Months)'),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    int.tryParse(val!) == null ? 'Invalid tenure' : null,
              ),

              const SizedBox(height: 16),

              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _presentDatePicker,
              ),

              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Estimated Monthly EMI',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$currencySymbol${_calculatedEMI.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 24,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (Optional)',
                ),
                maxLines: 2,
              ),

              const SizedBox(height: 24),

              ElevatedButton(
                onPressed: _submitData,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(isEditing ? 'Update Loan' : 'Save Loan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
