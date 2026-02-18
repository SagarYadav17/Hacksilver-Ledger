import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/custom_drawer.dart';
import '../services/backup_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const CustomDrawer(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(
            context,
            'Appearance',
            Icons.palette_outlined,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  title: const Text('System Default'),
                  value: ThemeMode.system,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) => themeProvider.setThemeMode(value!),
                ),
                Divider(color: colorScheme.outlineVariant),
                RadioListTile<ThemeMode>(
                  title: const Text('Light Theme'),
                  value: ThemeMode.light,
                  groupValue: themeProvider.themeMode,
                  onChanged: (value) => themeProvider.setThemeMode(value!),
                ),
                Divider(color: colorScheme.outlineVariant),
                RadioListTile<ThemeMode>(
                  title: const Text('Dark Theme'),
                  value: ThemeMode.dark,
                  groupValue: themeProvider.themeMode,
                  onChanged: (val) {
                    if (val != null) {
                      themeProvider.setThemeMode(val);
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(
            context,
            'Accent Color',
            Icons.color_lens_outlined,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildColorOption(
                  context,
                  themeProvider,
                  Colors.blueGrey,
                  'Slate',
                ),
                _buildColorOption(context, themeProvider, Colors.cyan, 'Frost'),
                _buildColorOption(
                  context,
                  themeProvider,
                  Colors.red[700]!,
                  'Spartan',
                ),
                _buildColorOption(
                  context,
                  themeProvider,
                  Colors.teal,
                  'Forest',
                ),
                _buildColorOption(
                  context,
                  themeProvider,
                  Colors.amber[700]!,
                  'Gold',
                ),
                _buildColorOption(
                  context,
                  themeProvider,
                  Colors.deepPurple,
                  'Mystic',
                ),
                _buildColorOption(
                  context,
                  themeProvider,
                  Colors.brown,
                  'Earth',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(
            context,
            'Currency',
            Icons.currency_exchange_outlined,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Consumer<CurrencyProvider>(
              builder: (context, currencyProvider, child) {
                return ListTile(
                  title: const Text('Default Currency'),
                  subtitle: Text(currencyProvider.currency),
                  trailing: DropdownButton<String>(
                    value:
                        [
                          'INR',
                          'USD',
                          'EUR',
                          'GBP',
                        ].contains(currencyProvider.currency)
                        ? currencyProvider.currency
                        : 'INR',
                    items: const [
                      DropdownMenuItem(
                        value: 'INR',
                        child: Text('INR (₹)'),
                      ),
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('USD (\$)'),
                      ),
                      DropdownMenuItem(
                        value: 'EUR',
                        child: Text('EUR (€)'),
                      ),
                      DropdownMenuItem(
                        value: 'GBP',
                        child: Text('GBP (£)'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        currencyProvider.setCurrency(val);
                      }
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(
            context,
            'Data Management',
            Icons.storage_outlined,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.download_outlined,
                      color: colorScheme.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Backup Data'),
                  subtitle: const Text('Export database to a file'),
                  onTap: () async {
                    await BackupService().exportDatabase(context);
                  },
                ),
                Divider(color: colorScheme.outlineVariant),
                ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.upload_outlined,
                      color: colorScheme.onSecondaryContainer,
                      size: 20,
                    ),
                  ),
                  title: const Text('Restore Data'),
                  subtitle: const Text('Import database from a file'),
                  onTap: () async {
                    // Confirm dialog
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Restore Database'),
                        content: const Text(
                          'This will overwrite your current data. Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(ctx);
                              await BackupService()
                                  .restoreDatabase(context);
                            },
                            child: const Text('Restore'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    ThemeProvider provider,
    Color color,
    String label,
  ) {
    final isSelected = provider.seedColor.value == color.value;
    return GestureDetector(
      onTap: () => provider.setSeedColor(color),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(14),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 2.5,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 24,
                  )
                : null,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
