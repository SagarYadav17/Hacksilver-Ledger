import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/recurring_transaction.dart';
import '../models/category.dart';
import '../providers/recurring_transaction_provider.dart';
import '../providers/category_provider.dart';
import '../utils/icon_utils.dart';
import '../utils/amount_colors.dart';

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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: plannedColor(
                      Theme.of(context).colorScheme,
                    ).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_month_outlined,
                        color: plannedColor(Theme.of(context).colorScheme),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Plan it once. Add entries automatically on schedule.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _SectionLabel(text: 'DETAILS'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. Rent, Salary, Netflix',
                    prefixIcon: Icon(Icons.edit_outlined),
                    filled: true,
                  ),
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
                    prefixIcon: Icon(Icons.payments_outlined),
                    filled: true,
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

                const SizedBox(height: 24),
                _SectionLabel(text: 'TYPE'),
                const SizedBox(height: 4),
                RadioGroup<CategoryType>(
                  groupValue: _selectedType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedType = value;
                        _selectedCategoryId = null; // Reset category
                      });
                    }
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: RadioListTile<CategoryType>(
                          title: const Text('Expense'),
                          value: CategoryType.expense,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<CategoryType>(
                          title: const Text('Income'),
                          value: CategoryType.income,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const SizedBox(height: 24),
                _SectionLabel(text: 'SCHEDULE'),
                const SizedBox(height: 8),
                Consumer<CategoryProvider>(
                  builder: (context, categoryProvider, child) {
                    final categories = categoryProvider.categories
                        .where((c) => c.type == _selectedType)
                        .toList();

                    return DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        filled: true,
                      ),
                      hint: const Text('Select category'),
                      items: categories.map((cat) {
                        return DropdownMenuItem(
                          value: cat.id,
                          child: Row(
                            children: [
                              Icon(
                                categoryIconData(
                                  cat.iconCode,
                                  fontFamily: cat.fontFamily,
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

                DropdownButtonFormField<Frequency>(
                  initialValue: _selectedFrequency,
                  decoration: const InputDecoration(
                    labelText: 'Frequency',
                    filled: true,
                  ),
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

                Card(
                  elevation: 0,
                  child: ListTile(
                    leading: Icon(
                      Icons.calendar_today_outlined,
                      color: plannedColor(Theme.of(context).colorScheme),
                    ),
                    title: const Text('Start date'),
                    subtitle: Text(DateFormat.yMMMd().format(_startDate)),
                    trailing: const Icon(Icons.calendar_month_outlined),
                    onTap: _presentDatePicker,
                  ),
                ),
                const SizedBox(height: 24),

                // Save Button
                FilledButton(
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

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: Theme.of(context).textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w700,
      letterSpacing: 0.7,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}
