import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/security_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../services/backup_service.dart';
import '../utils/security_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize sync provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SyncProvider>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/settings'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionHeader(context, 'Manage', Icons.apps_outlined),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: Column(
              children: [
                _buildNavigationTile(
                  context,
                  icon: Icons.category_outlined,
                  title: 'Categories',
                  subtitle: 'Manage income and expense categories',
                  route: '/categories',
                ),
                Divider(color: colorScheme.outlineVariant),
                _buildNavigationTile(
                  context,
                  icon: Icons.event_repeat_outlined,
                  title: 'Recurring',
                  subtitle: 'Manage scheduled transactions',
                  route: '/recurring-transactions',
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(context, 'Appearance', Icons.palette_outlined),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: RadioGroup<ThemeMode>(
              groupValue: themeProvider.themeMode,
              onChanged: (value) {
                if (value != null) {
                  themeProvider.setThemeMode(value);
                }
              },
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: const Text('System Default'),
                    value: ThemeMode.system,
                  ),
                  Divider(color: colorScheme.outlineVariant),
                  RadioListTile<ThemeMode>(
                    title: const Text('Light Theme'),
                    value: ThemeMode.light,
                  ),
                  Divider(color: colorScheme.outlineVariant),
                  RadioListTile<ThemeMode>(
                    title: const Text('Dark Theme'),
                    value: ThemeMode.dark,
                  ),
                ],
              ),
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
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
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
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(context, 'Security', Icons.lock_outline),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: Consumer<SecurityProvider>(
              builder: (context, securityProvider, child) {
                return Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.visibility_off_outlined),
                      title: const Text('Hide balances'),
                      subtitle: const Text('Mask amounts on money screens'),
                      value: securityProvider.hideBalances,
                      onChanged: securityProvider.setHideBalances,
                    ),
                    Divider(color: colorScheme.outlineVariant),
                    SwitchListTile(
                      secondary: const Icon(Icons.lock_outline_rounded),
                      title: const Text('App lock'),
                      subtitle: Text(
                        securityProvider.hasPin
                            ? 'Require PIN when opening the app'
                            : 'Set a PIN before enabling app lock',
                      ),
                      value: securityProvider.appLockEnabled,
                      onChanged: (value) async {
                        if (value && !securityProvider.hasPin) {
                          await _showSetPinDialog(context, securityProvider);
                          return;
                        }
                        await securityProvider.setAppLockEnabled(value);
                      },
                    ),
                    Divider(color: colorScheme.outlineVariant),
                    ListTile(
                      leading: const Icon(Icons.pin_outlined),
                      title: Text(
                        securityProvider.hasPin ? 'Change PIN' : 'Set PIN',
                      ),
                      subtitle: const Text('Use a 4-8 digit app lock PIN'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () =>
                          _showSetPinDialog(context, securityProvider),
                    ),
                    if (securityProvider.hasPin) ...[
                      Divider(color: colorScheme.outlineVariant),
                      ListTile(
                        leading: Icon(
                          Icons.lock_open_outlined,
                          color: colorScheme.error,
                        ),
                        title: Text(
                          'Remove PIN',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        subtitle: const Text('Disable app lock on this device'),
                        onTap: () =>
                            _showClearPinDialog(context, securityProvider),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(context, 'Cloud Sync', Icons.cloud_sync_outlined),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
            ),
            child: Consumer<SyncProvider>(
              builder: (context, syncProvider, child) {
                return Column(
                  children: [
                    // Configuration status
                    ListTile(
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: syncProvider.isConfigured
                              ? colorScheme.tertiaryContainer
                              : colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          syncProvider.isConfigured
                              ? Icons.cloud_done_outlined
                              : Icons.cloud_off_outlined,
                          color: syncProvider.isConfigured
                              ? colorScheme.onTertiaryContainer
                              : colorScheme.onErrorContainer,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        syncProvider.isConfigured
                            ? 'Cloud Sync Enabled'
                            : 'Cloud Sync Disabled',
                      ),
                      subtitle: Text(
                        syncProvider.isConfigured
                            ? syncProvider.supabaseUrl ?? 'Connected'
                            : 'Configure Supabase to enable sync',
                      ),
                      trailing: syncProvider.isConfigured
                          ? IconButton(
                              icon: const Icon(Icons.settings_outlined),
                              onPressed: () =>
                                  _showSyncConfigDialog(context, syncProvider),
                            )
                          : FilledButton.tonal(
                              onPressed: () =>
                                  _showSyncConfigDialog(context, syncProvider),
                              child: const Text('Setup'),
                            ),
                    ),

                    if (syncProvider.isConfigured) ...[
                      Divider(color: colorScheme.outlineVariant),
                      // Sync status info
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Pending Items',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    '${syncProvider.pendingCount}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Last Sync',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                  Text(
                                    syncProvider.lastSyncAt != null
                                        ? _formatDateTime(
                                            syncProvider.lastSyncAt!,
                                          )
                                        : 'Never',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Error message if any
                      if (syncProvider.lastError != null)
                        Container(
                          margin: const EdgeInsets.all(16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: colorScheme.errorContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.error_outline,
                                color: colorScheme.onErrorContainer,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  syncProvider.lastError!,
                                  style: TextStyle(
                                    color: colorScheme.onErrorContainer,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                      Divider(color: colorScheme.outlineVariant),
                      // Sync action
                      ListTile(
                        leading: syncProvider.isSyncing
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: colorScheme.primary,
                                ),
                              )
                            : Icon(
                                Icons.sync_outlined,
                                color: colorScheme.primary,
                              ),
                        title: Text(
                          syncProvider.isSyncing ? 'Syncing...' : 'Sync Now',
                        ),
                        subtitle: Text(
                          syncProvider.isSyncing
                              ? 'Uploading data to cloud...'
                              : 'Upload pending changes to Supabase',
                        ),
                        onTap: syncProvider.isSyncing
                            ? null
                            : () => _performSync(context, syncProvider),
                      ),

                      if (syncProvider.syncHistory.isNotEmpty) ...[
                        Divider(color: colorScheme.outlineVariant),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Recent sync history',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                          ),
                        ),
                        for (final item in syncProvider.syncHistory)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              item['status'] == 'success'
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: item['status'] == 'success'
                                  ? colorScheme.tertiary
                                  : colorScheme.error,
                            ),
                            title: Text(
                              item['status'] == 'success'
                                  ? '${item['syncedCount']} item(s) uploaded'
                                  : 'Sync failed',
                            ),
                            subtitle: Text(
                              _syncHistorySubtitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],

                      Divider(color: colorScheme.outlineVariant),
                      // Disconnect action
                      ListTile(
                        leading: Icon(
                          Icons.logout_outlined,
                          color: colorScheme.error,
                        ),
                        title: Text(
                          'Disconnect',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        subtitle: const Text('Clear cloud sync configuration'),
                        onTap: () =>
                            _showDisconnectDialog(context, syncProvider),
                      ),
                    ],
                  ],
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
              side: BorderSide(color: colorScheme.outlineVariant, width: 0.5),
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
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inHours < 1) {
      return '${diff.inMinutes} min ago';
    } else if (diff.inDays < 1) {
      return '${diff.inHours} hours ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }

  String _syncHistorySubtitle(Map<String, dynamic> item) {
    final createdAt = DateTime.tryParse('${item['createdAt']}');
    final time = createdAt != null ? _formatDateTime(createdAt) : 'Unknown time';
    final message = item['message'] as String?;
    if (message == null || message.isEmpty || item['status'] == 'success') {
      return time;
    }
    return '$time • $message';
  }

  Future<void> _showSetPinDialog(
    BuildContext context,
    SecurityProvider securityProvider,
  ) {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(securityProvider.hasPin ? 'Change PIN' : 'Set PIN'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                decoration: const InputDecoration(
                  labelText: 'PIN',
                  prefixIcon: Icon(Icons.pin_outlined),
                  counterText: '',
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                validator: (value) {
                  final pin = value?.trim() ?? '';
                  if (pin.length < 4 || pin.length > 8) {
                    return 'PIN must be 4-8 digits';
                  }
                  if (!RegExp(r'^\d+$').hasMatch(pin)) {
                    return 'Use digits only';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmController,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  prefixIcon: Icon(Icons.check_circle_outline),
                  counterText: '',
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 8,
                validator: (value) {
                  if ((value?.trim() ?? '') != pinController.text.trim()) {
                    return 'PINs do not match';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await securityProvider.setPin(pinController.text.trim());
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN saved')),
              );
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() {
      pinController.dispose();
      confirmController.dispose();
    });
  }

  Future<void> _showClearPinDialog(
    BuildContext context,
    SecurityProvider securityProvider,
  ) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove PIN?'),
        content: const Text('App lock will be disabled on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await securityProvider.clearPin();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('PIN removed')),
              );
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSyncConfigDialog(
    BuildContext context,
    SyncProvider syncProvider,
  ) {
    final urlController = TextEditingController();
    final keyController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Configure Cloud Sync'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: urlController,
                decoration: const InputDecoration(
                  labelText: 'Supabase Project URL',
                  hintText: 'https://your-project.supabase.co',
                  prefixIcon: Icon(Icons.link_outlined),
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the Supabase URL';
                  }
                  if (!value.startsWith('https://')) {
                    return 'URL must start with https://';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: keyController,
                decoration: const InputDecoration(
                  labelText: 'Anon Key',
                  hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                  prefixIcon: Icon(Icons.key_outlined),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter the anon key';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Your credentials are stored locally on this device.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                // Validate URL securely
                final urlValidation = SecurityUtils.validateSupabaseUrl(
                  urlController.text.trim(),
                );
                if (!urlValidation.isValid) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(urlValidation.errorMessage!),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                // Validate key
                final key = keyController.text.trim();
                if (key.length < 20) {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Invalid API key'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.pop(ctx);

                // Show loading
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (ctx) =>
                      const Center(child: CircularProgressIndicator()),
                );

                // Try to configure
                final success = await syncProvider.configureSupabase(
                  urlValidation.value,
                  key,
                );

                if (mounted) {
                  Navigator.pop(this.context); // Close loading

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'Cloud sync configured successfully!'
                            : syncProvider.lastError ??
                                  'Failed to configure sync',
                      ),
                      backgroundColor: success ? Colors.green : null,
                    ),
                  );
                }
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _performSync(
    BuildContext context,
    SyncProvider syncProvider,
  ) async {
    final result = await syncProvider.syncNow();

    if (mounted) {
      if (result.success) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(
              'Sync complete! ${result.syncedCount} items uploaded.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text(result.errorMessage ?? 'Sync failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showDisconnectDialog(
    BuildContext context,
    SyncProvider syncProvider,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect Cloud Sync'),
        content: const Text(
          'This will remove your Supabase configuration from this device. '
          'Your local data will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await syncProvider.clearConfiguration();
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Cloud sync disconnected')),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Disconnect'),
          ),
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
          child: Icon(icon, color: colorScheme.onPrimaryContainer, size: 18),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: colorScheme.onSecondaryContainer, size: 20),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(route),
    );
  }

}

// Simple RadioGroup wrapper widget
class RadioGroup<T> extends StatelessWidget {
  final T? groupValue;
  final ValueChanged<T?>? onChanged;
  final Widget child;

  const RadioGroup({
    super.key,
    required this.groupValue,
    required this.onChanged,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _RadioGroupScope(
      groupValue: groupValue,
      onChanged: onChanged != null ? (dynamic v) => onChanged!(v as T?) : null,
      child: child,
    );
  }
}

class _RadioGroupScope extends InheritedWidget {
  final dynamic groupValue;
  final ValueChanged<dynamic>? onChanged;

  const _RadioGroupScope({
    required this.groupValue,
    required this.onChanged,
    required super.child,
  });

  @override
  bool updateShouldNotify(_RadioGroupScope old) => groupValue != old.groupValue;
}
