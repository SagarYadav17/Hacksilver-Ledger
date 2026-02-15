import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/loan.dart';
import '../providers/loan_provider.dart';

class AddLoanScreen extends StatefulWidget {
  const AddLoanScreen({super.key});

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

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_updateEMI);
    _rateController.addListener(_updateEMI);
    _tenureController.addListener(_updateEMI);
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

  void _submitData() {
    if (_formKey.currentState!.validate()) {
      final newLoan = Loan(
        title: _titleController.text,
        amount: double.parse(_amountController.text),
        interestRate: double.parse(_rateController.text),
        tenureMonths: int.parse(_tenureController.text),
        type: _type,
        startDate: _startDate,
        emiAmount: _calculatedEMI,
        notes: _notesController.text.isEmpty ? null : _notesController.text,
      );

      Provider.of<LoanProvider>(context, listen: false).addLoan(newLoan);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Add Loan')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // Type Selection
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<LoanType>(
                      title: const Text('Loan Taken'),
                      value: LoanType.taken,
                      groupValue: _type,
                      onChanged: (val) => setState(() => _type = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<LoanType>(
                      title: const Text('Loan Given'),
                      value: LoanType.given,
                      groupValue: _type,
                      onChanged: (val) => setState(() => _type = val!),
                    ),
                  ),
                ],
              ),

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title (e.g. Home Loan)',
                ),
                validator: (val) => val!.isEmpty ? 'Enter a title' : null,
              ),

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

              TextFormField(
                controller: _tenureController,
                decoration: const InputDecoration(labelText: 'Tenure (Months)'),
                keyboardType: TextInputType.number,
                validator: (val) =>
                    int.tryParse(val!) == null ? 'Invalid tenure' : null,
              ),

              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: _presentDatePicker,
              ),

              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
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
                      '\$${_calculatedEMI.toStringAsFixed(2)}',
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
                child: const Text('Save Loan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
