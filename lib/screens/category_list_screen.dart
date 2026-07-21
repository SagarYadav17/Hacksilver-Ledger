import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../constants/app_constants.dart';
import '../providers/category_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/transaction_provider.dart';
import '../models/category.dart';
import '../utils/icon_utils.dart';

class CategoryListScreen extends StatelessWidget {
  const CategoryListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Categories'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Expense'),
              Tab(text: 'Income'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            CategoryList(type: CategoryType.expense),
            CategoryList(type: CategoryType.income),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            _showAddCategoryDialog(context);
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showAddCategoryDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => const AddCategoryDialog());
  }
}

class CategoryList extends StatelessWidget {
  final CategoryType type;
  const CategoryList({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final currency = context.watch<CurrencyProvider>().currency;
    final formatter = NumberFormat.currency(
      symbol: AppConstants.currencySymbols[currency] ?? currency,
      decimalDigits: 2,
    );

    return Consumer2<CategoryProvider, TransactionProvider>(
      builder: (context, categoryProvider, transactionProvider, child) {
        final allOfType = categoryProvider.categories
            .where((c) => c.type == type)
            .toList();
        final active = allOfType.where((c) => !c.isArchived).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        final archived = allOfType.where((c) => c.isArchived).toList();
        final transactions = transactionProvider.transactions
            .where((tx) => tx.type == type)
            .toList();
        final totalAmount = transactions.fold<double>(
          0,
          (sum, tx) => sum + tx.amount,
        );

        if (allOfType.isEmpty) {
          return const Center(child: Text('No categories found.'));
        }

        return ListView(
          padding: const EdgeInsets.only(bottom: 16),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text('This month · drag to reorder'),
            ),
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: active.length,
              onReorder: (oldIndex, newIndex) {
                if (newIndex > oldIndex) newIndex -= 1;
                final reordered = List<Category>.from(active);
                final moved = reordered.removeAt(oldIndex);
                reordered.insert(newIndex, moved);
                categoryProvider.reorderCategories(reordered);
              },
              itemBuilder: (context, index) {
                final cat = active[index];
                return _CategoryRow(
                  key: ValueKey(cat.id),
                  category: cat,
                  transactions: transactions,
                  totalAmount: totalAmount,
                  formatter: formatter,
                  otherCategories: active
                      .where((c) => c.id != cat.id)
                      .toList(),
                );
              },
            ),
            if (archived.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 4),
                child: Text('Archived'),
              ),
              for (final cat in archived)
                Opacity(
                  opacity: 0.55,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Color(
                        cat.colorValue,
                      ).withValues(alpha: 0.2),
                      child: Icon(
                        categoryIconData(
                          cat.iconCode,
                          fontFamily: cat.fontFamily,
                          fontPackage: cat.fontPackage,
                        ),
                        color: Color(cat.colorValue),
                      ),
                    ),
                    title: Text('${cat.name} — archived'),
                    subtitle: const Text(
                      'Hidden from pickers, history kept',
                    ),
                    trailing: TextButton(
                      onPressed: () =>
                          categoryProvider.unarchiveCategory(cat.id!),
                      child: const Text('Unarchive'),
                    ),
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final Category category;
  final List<dynamic> transactions;
  final double totalAmount;
  final NumberFormat formatter;
  final List<Category> otherCategories;

  const _CategoryRow({
    super.key,
    required this.category,
    required this.transactions,
    required this.totalAmount,
    required this.formatter,
    required this.otherCategories,
  });

  @override
  Widget build(BuildContext context) {
    final cat = category;
    final categoryTransactions = transactions
        .where((tx) => tx.categoryId == cat.id)
        .toList();
    final usageCount = categoryTransactions.length;
    final usageAmount = categoryTransactions.fold<double>(
      0,
      (sum, tx) => sum + tx.amount,
    );
    final share = totalAmount == 0 ? 0.0 : usageAmount / totalAmount;
    final categoryColor = Color(cat.colorValue);
    final categoryProvider = context.read<CategoryProvider>();

    return ListTile(
      leading: const Icon(Icons.drag_indicator),
      title: Row(
        children: [
          CircleAvatar(
            radius: 19,
            backgroundColor: categoryColor.withValues(alpha: 0.2),
            child: Icon(
              categoryIconData(
                cat.iconCode,
                fontFamily: cat.fontFamily,
                fontPackage: cat.fontPackage,
              ),
              color: categoryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(cat.name)),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(left: 50),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              usageCount == 0
                  ? 'No transactions'
                  : '$usageCount ${usageCount == 1 ? 'entry' : 'entries'} · ${(share * 100).toStringAsFixed(0)}% of spend',
            ),
            if (usageCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 4,
                  backgroundColor: categoryColor.withValues(alpha: 0.12),
                  color: categoryColor,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) {
          switch (action) {
            case 'edit':
              showDialog(
                context: context,
                builder: (ctx) => AddCategoryDialog(existing: cat),
              );
              break;
            case 'merge':
              _showMergeDialog(context, categoryProvider);
              break;
            case 'archive':
              categoryProvider.archiveCategory(cat.id!);
              break;
            case 'delete':
              _confirmDelete(context, categoryProvider);
              break;
          }
        },
        itemBuilder: (ctx) => [
          const PopupMenuItem(value: 'edit', child: Text('Edit')),
          if (otherCategories.isNotEmpty)
            const PopupMenuItem(value: 'merge', child: Text('Merge into…')),
          const PopupMenuItem(value: 'archive', child: Text('Archive')),
          if (cat.isCustom)
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, CategoryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category?'),
        content: const Text(
          'This will not delete existing transactions, but they will lose this category association.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteCategory(category.id!);
              Navigator.of(ctx).pop();
            },
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  void _showMergeDialog(BuildContext context, CategoryProvider provider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Merge "${category.name}" into…'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: otherCategories.length,
            itemBuilder: (context, index) {
              final target = otherCategories[index];
              return ListTile(
                leading: Icon(
                  categoryIconData(
                    target.iconCode,
                    fontFamily: target.fontFamily,
                    fontPackage: target.fontPackage,
                  ),
                  color: Color(target.colorValue),
                ),
                title: Text(target.name),
                onTap: () {
                  provider.mergeCategories(category.id!, target.id!);
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}

class AddCategoryDialog extends StatefulWidget {
  final Category? existing;

  const AddCategoryDialog({super.key, this.existing});

  @override
  State<AddCategoryDialog> createState() => _AddCategoryDialogState();
}

class _AddCategoryDialogState extends State<AddCategoryDialog> {
  late final _nameController = TextEditingController(
    text: widget.existing?.name ?? '',
  );
  late CategoryType _type = widget.existing?.type ?? CategoryType.expense;
  late IconData _selectedIcon = widget.existing != null
      ? categoryIconData(
          widget.existing!.iconCode,
          fontFamily: widget.existing!.fontFamily,
          fontPackage: widget.existing!.fontPackage,
        )
      : Icons.fastfood;
  late int _selectedColor = widget.existing?.colorValue ?? 0xFFF44336;

  final List<IconData> _availableIcons = [
    Icons.fastfood,
    Icons.restaurant,
    Icons.lunch_dining,
    Icons.local_cafe,
    Icons.local_bar,
    Icons.commute,
    Icons.directions_car,
    Icons.directions_bus,
    Icons.flight,
    Icons.local_gas_station,
    Icons.shopping_cart,
    Icons.shopping_bag,
    Icons.checkroom,
    Icons.movie,
    Icons.sports_soccer,
    Icons.fitness_center,
    Icons.health_and_safety,
    Icons.medical_services,
    Icons.local_hospital,
    Icons.local_pharmacy,
    Icons.person,
    Icons.work,
    Icons.business_center,
    Icons.home,
    Icons.cottage,
    Icons.school,
    Icons.pets,
    Icons.account_balance,
    Icons.credit_card,
    Icons.savings,
    Icons.attach_money,
    Icons.trending_up,
    Icons.trending_down,
    Icons.power,
    Icons.wifi,
    Icons.phone_android,
    Icons.computer,
    Icons.gamepad,
    Icons.headset,
    Icons.book,
    Icons.celebration,
    Icons.cleaning_services,
    Icons.construction,
    Icons.weekend,
    Icons.family_restroom,
    Icons.child_care,
    Icons.park,
    Icons.beach_access,
    Icons.local_grocery_store,
    Icons.local_mall,
  ];

  final List<int> _availableColors = [
    0xFFF44336, // Red
    0xFFE91E63, // Pink
    0xFF9C27B0, // Purple
    0xFF673AB7, // Deep Purple
    0xFF3F51B5, // Indigo
    0xFF2196F3, // Blue
    0xFF03A9F4, // Light Blue
    0xFF00BCD4, // Cyan
    0xFF009688, // Teal
    0xFF4CAF50, // Green
    0xFF8BC34A, // Light Green
    0xFFCDDC39, // Lime
    0xFFFFEB3B, // Yellow
    0xFFFFC107, // Amber
    0xFFFF9800, // Orange
    0xFFFF5722, // Deep Orange
    0xFF795548, // Brown
    0xFF9E9E9E, // Grey
    0xFF607D8B, // Blue Grey
    0xFF000000, // Black
  ];

  void _pickIcon() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Select Icon',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _availableIcons.length,
                    itemBuilder: (context, index) {
                      final icon = _availableIcons[index];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _selectedIcon = icon;
                          });
                          Navigator.pop(context);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                            border: _selectedIcon == icon
                                ? Border.all(
                                    color: Theme.of(context).primaryColor,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Icon(
                            icon,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Category' : 'Add Category'),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Category Name'),
          ),
          const SizedBox(height: 16),
          RadioGroup<CategoryType>(
            groupValue: _type,
            onChanged: (value) {
              if (value != null) {
                setState(() => _type = value);
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: RadioListTile<CategoryType>(
                    title: const Text('Expense'),
                    value: CategoryType.expense,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
                Expanded(
                  child: RadioListTile<CategoryType>(
                    title: const Text('Income'),
                    value: CategoryType.income,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Text('Select Icon'),
          const SizedBox(height: 8),
          Center(
            child: InkWell(
              onTap: _pickIcon,
              child: CircleAvatar(
                radius: 30,
                backgroundColor: Color(_selectedColor),
                child: Icon(_selectedIcon, color: Colors.white, size: 30),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(child: Text('Tap to change icon')),
          const SizedBox(height: 16),
          const Text('Select Color'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: _availableColors.map((color) {
              return InkWell(
                onTap: () => setState(() => _selectedColor = color),
                child: CircleAvatar(
                  backgroundColor: Color(color),
                  child: _selectedColor == color
                      ? const Icon(Icons.check_rounded, color: Colors.white)
                      : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_nameController.text.isEmpty) return;

            final provider = Provider.of<CategoryProvider>(
              context,
              listen: false,
            );

            if (widget.existing != null) {
              provider.updateCategory(
                widget.existing!.copyWith(
                  name: _nameController.text,
                  iconCode: _selectedIcon.codePoint,
                  fontFamily: _selectedIcon.fontFamily,
                  fontPackage: _selectedIcon.fontPackage,
                  colorValue: _selectedColor,
                  type: _type,
                ),
              );
            } else {
              provider.addCategory(
                Category(
                  name: _nameController.text,
                  iconCode: _selectedIcon.codePoint,
                  fontFamily: _selectedIcon.fontFamily,
                  fontPackage: _selectedIcon.fontPackage,
                  colorValue: _selectedColor,
                  type: _type,
                  isCustom: true,
                ),
              );
            }
            Navigator.pop(context);
          },
          child: Text(widget.existing != null ? 'Save' : 'Add'),
        ),
      ],
    );
  }
}
