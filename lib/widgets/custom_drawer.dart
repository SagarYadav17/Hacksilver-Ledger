import 'package:flutter/material.dart';

class CustomDrawer extends StatelessWidget {
  final String currentRoute;

  const CustomDrawer({super.key, required this.currentRoute});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return NavigationDrawer(
      selectedIndex: _getSelectedIndex(currentRoute),
      onDestinationSelected: (index) {
        _onDestinationSelected(context, index);
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 16, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: colorScheme.primary,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Hacksilver Ledger',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.dashboard_outlined),
          selectedIcon: Icon(Icons.dashboard),
          label: Text('Dashboard'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: Text('Transactions'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.event_repeat_outlined),
          selectedIcon: Icon(Icons.event_repeat),
          label: Text('Recurring'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.credit_score_outlined),
          selectedIcon: Icon(Icons.credit_score),
          label: Text('Loans'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.account_balance_outlined),
          selectedIcon: Icon(Icons.account_balance),
          label: Text('Accounts'),
        ),
        const Divider(),
        const NavigationDrawerDestination(
          icon: Icon(Icons.category_outlined),
          selectedIcon: Icon(Icons.category),
          label: Text('Categories'),
        ),
        const Divider(),
        const NavigationDrawerDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: Text('Settings'),
        ),
      ],
    );
  }

  int _getSelectedIndex(String route) {
    switch (route) {
      case '/':
        return 0;
      case '/transactions':
        return 1;
      case '/recurring-transactions':
        return 2;
      case '/loans':
        return 3;
      case '/accounts':
        return 4;
      case '/categories':
        return 5; // Divider is not an index, but destinations are indexed sequentially? NO.
      // NavigationDrawer counts EVERYTHING or just destinations?
      // It counts destinations only for index.
      // Divider is a widget, not a destination.
      // Let's verify index counting. Widgets that are text/divider are NOT destinations.
      // But children list includes them.
      // Flutter's NavigationDrawer `selectedIndex` corresponds to the index of the *highlighted destination*.
      // It does NOT correspond to the index in the `children` list.
      // Wait, checking docs... "The selectedIndex property ... selects the destination tile at that index."
      // So I need to count the destinations.
      case '/settings':
        return 6;
      default:
        return 0;
    }
  }

  void _onDestinationSelected(BuildContext context, int index) {
    // Close drawer first? NavigationDrawer usually stays handling selection,
    // but in a Drawer slot of Scaffold, we should close it or just navigate.
    // If we are pushing routes, we should probably close it.
    // However, typical NavigationDrawer in Scaffold.drawer replaces the screen content.
    Navigator.pop(context); // Close drawer

    switch (index) {
      case 0:
        if (currentRoute != '/') {
          Navigator.of(context).pushReplacementNamed('/');
        }
        break;
      case 1:
        if (currentRoute != '/transactions') {
          Navigator.of(context).pushNamed('/transactions');
        }
        break;
      case 2:
        if (currentRoute != '/recurring-transactions') {
          Navigator.of(context).pushNamed('/recurring-transactions');
        }
        break;
      case 3:
        if (currentRoute != '/loans') {
          Navigator.of(context).pushNamed('/loans');
        }
        break;
      case 4:
        if (currentRoute != '/accounts') {
          Navigator.of(context).pushNamed('/accounts');
        }
        break;
      case 5:
        if (currentRoute != '/categories') {
          Navigator.of(context).pushNamed('/categories');
        }
        break;
      case 6:
        if (currentRoute != '/settings') {
          Navigator.of(context).pushNamed('/settings');
        }
        break;
    }
  }
}
