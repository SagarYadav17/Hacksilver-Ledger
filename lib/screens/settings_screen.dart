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

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      drawer: const CustomDrawer(currentRoute: '/settings'),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('System Default'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (value) => themeProvider.setThemeMode(value!),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('Light Theme'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (value) => themeProvider.setThemeMode(value!),
          ),
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Accent Color',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Currency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          Consumer<CurrencyProvider>(
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
                    DropdownMenuItem(value: 'INR', child: Text('INR (₹)')),
                    DropdownMenuItem(value: 'USD', child: Text('USD (\$)')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR (€)')),
                    DropdownMenuItem(value: 'GBP', child: Text('GBP (£)')),
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
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Data Management',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Backup Data'),
            subtitle: const Text('Export database to a file'),
            onTap: () async {
              await BackupService().exportDatabase(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
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
                        await BackupService().restoreDatabase(context);
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    )
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check_rounded, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
