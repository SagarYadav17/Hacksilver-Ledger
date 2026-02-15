import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/category_provider.dart';

class AddRecurringTransactionScreen extends StatefulWidget {
  const AddRecurringTransactionScreen({super.key});

  @override
  State<AddRecurringTransactionScreen> createState() =>
      _AddRecurringTransactionScreenState();
}

class _AddRecurringTransactionScreenState
    extends State<AddRecurringTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime _startDate = DateTime.now();
  CategoryType _selectedType = CategoryType.expense;
  int? _selectedCategoryId;
  Frequency _selectedFrequency = Frequency.monthly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Recurring Transaction')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Amount
                TextFormField(
                  controller: _amountController,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    prefixText: '\$ ',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter an amount';
                    }
                    if (double.tryParse(value) == null) {
                      return 'Please enter a valid number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Type Selection
                Row(
                  children: [
                    Expanded(
                      child: RadioListTile<CategoryType>(
                        title: const Text('Expense'),
                        value: CategoryType.expense,
                        groupValue: _selectedType,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _selectedCategoryId = null; // Reset category
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: RadioListTile<CategoryType>(
                        title: const Text('Income'),
                        value: CategoryType.income,
                        groupValue: _selectedType,
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                            _selectedCategoryId = null; // Reset category
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Category Dropdown
                Consumer<CategoryProvider>(
                  builder: (context, categoryProvider, child) {
                    final categories = categoryProvider.categories
                        .where((c) => c.type == _selectedType)
                        .toList();

                    return DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      hint: const Text('Select Category'),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Row(
                            children: [
                              Icon(
                                IconData(
                                  cat.iconCode,
                                  fontFamily: cat.fontFamily ?? 'MaterialIcons',
                                  fontPackage: cat.fontPackage,
                                ),
                                color: Color(cat.colorValue),
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Text(cat.name),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                        });
                      },
                      validator: (value) =>
                          value == null ? 'Please select a category' : null,
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Frequency Dropdown
                DropdownButtonFormField<Frequency>(
                  initialValue: _selectedFrequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: Frequency.values.map((f) {
                    String label = f.toString().split('.').last;
                    label = label[0].toUpperCase() + label.substring(1);
                    return DropdownMenuItem(value: f, child: Text(label));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedFrequency = value!;
                    });
                  },
                ),
                const SizedBox(height: 16),

                // Start Date Picker
                ListTile(
                  title: const Text('Start Date'),
                  subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _presentDatePicker,
                ),
                const SizedBox(height: 24),

                // Save Button
                ElevatedButton(
                  onPressed: _saveRecurringTransaction,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text(
                    'Save Recurring Transaction',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _presentDatePicker() {
    showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _startDate = pickedDate;
      });
    });
  }

  void _saveRecurringTransaction() {
    if (!_formKey.currentState!.validate()) return;

    final newRecurring = RecurringTransaction(
      title: _titleController.text,
      amount: double.parse(_amountController.text),
      type: _selectedType,
      categoryId: _selectedCategoryId!,
      frequency: _selectedFrequency,
      startDate: _startDate,
      nextDueDate: _startDate, // Initial next due is start date
      isActive: true,
    );

    Provider.of<RecurringTransactionProvider>(
      context,
      listen: false,
    ).addRecurringTransaction(newRecurring);

    Navigator.of(context).pop();
  }
}
