import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../providers/currency_provider.dart';
import '../providers/security_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/app_bottom_nav.dart';
import '../utils/amount_colors.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      bottomNavigationBar: const AppBottomNav(currentRoute: '/more'),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel(context, 'APPEARANCE'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.light,
                        label: Text('Light'),
                      ),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                      ButtonSegment(
                        value: ThemeMode.system,
                        label: Text('System'),
                      ),
                    ],
                    selected: {themeProvider.themeMode},
                    onSelectionChanged: (selection) =>
                        themeProvider.setThemeMode(selection.first),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Accent color',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final color in ThemeProvider.accentSwatches)
                        Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: GestureDetector(
                            onTap: () => themeProvider.setSeedColor(color),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border:
                                    themeProvider.seedColor.toARGB32() ==
                                        color.toARGB32()
                                    ? Border.all(
                                        color: colorScheme.onSurface,
                                        width: 2,
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Consumer<CurrencyProvider>(
              builder: (context, currencyProvider, child) {
                return ListTile(
                  title: const Text('Currency'),
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
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'INR', child: Text('₹ INR')),
                      DropdownMenuItem(value: 'USD', child: Text('\$ USD')),
                      DropdownMenuItem(value: 'EUR', child: Text('€ EUR')),
                      DropdownMenuItem(value: 'GBP', child: Text('£ GBP')),
                    ],
                    onChanged: (val) {
                      if (val != null) currencyProvider.setCurrency(val);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _sectionLabel(context, 'PRIVACY'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Consumer<SecurityProvider>(
              builder: (context, securityProvider, child) {
                return Column(
                  children: [
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
                    if (securityProvider.appLockEnabled ||
                        securityProvider.hasPin)
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: Text(
                          securityProvider.hasPin ? 'Change PIN' : 'Set PIN',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            _showSetPinDialog(context, securityProvider),
                      ),
                    Divider(color: colorScheme.outlineVariant, height: 1),
                    SwitchListTile(
                      secondary: const Icon(Icons.visibility_off_outlined),
                      title: const Text('Hide balances'),
                      subtitle: const Text('Mask amounts on money screens'),
                      value: securityProvider.hideBalances,
                      onChanged: securityProvider.setHideBalances,
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _sectionLabel(context, 'DATA'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return Column(
                  children: [
                    _navTile(
                      context,
                      icon: Icons.cloud_sync_outlined,
                      color: plannedColor(colorScheme),
                      title: 'Sync & backup',
                      subtitle: authProvider.isLoggedIn
                          ? 'Cloud copy connected'
                          : 'On this device only',
                      route: '/sync-backup',
                    ),
                    Divider(color: colorScheme.outlineVariant, height: 1),
                    _navTile(
                      context,
                      icon: Icons.category_outlined,
                      color: groupingColor(colorScheme),
                      title: 'Categories',
                      subtitle: 'Reorder, merge, archive',
                      route: '/categories',
                    ),
                    Divider(color: colorScheme.outlineVariant, height: 1),
                    _navTile(
                      context,
                      icon: Icons.event_repeat_outlined,
                      color: plannedColor(colorScheme),
                      title: 'Recurring',
                      subtitle: 'Manage scheduled transactions',
                      route: '/recurring-transactions',
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          _sectionLabel(context, 'HELP'),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: _navTile(
              context,
              icon: Icons.bug_report_outlined,
              color: groupingColor(colorScheme),
              title: 'Diagnostics & error log',
              subtitle: null,
              route: '/diagnostics',
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String? subtitle,
    required String route,
  }) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).pushNamed(route),
    );
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
          if (securityProvider.hasPin)
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(ctx).colorScheme.error,
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                await securityProvider.clearPin();
              },
              child: const Text('Remove PIN'),
            ),
          FilledButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              await securityProvider.setPin(pinController.text.trim());
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
}
