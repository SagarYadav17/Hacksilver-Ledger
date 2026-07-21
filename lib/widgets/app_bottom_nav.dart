import 'package:flutter/material.dart';
import '../screens/account_list_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/loan_list_screen.dart';
import '../screens/more_screen.dart';
import '../screens/transaction_list_screen.dart';

class AppBottomNav extends StatelessWidget {
  final String currentRoute;

  const AppBottomNav({super.key, required this.currentRoute});

  static const _routes = [
    '/',
    '/transactions',
    '/loans',
    '/accounts',
    '/more',
  ];

  int get _selectedIndex {
    final index = _routes.indexOf(currentRoute);
    return index == -1 ? 0 : index;
  }

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        final route = _routes[index];
        if (route == currentRoute) return;
        Navigator.of(context).pushReplacement(
          PageRouteBuilder<void>(
            settings: RouteSettings(name: route),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, _, _) => _screenForRoute(route),
          ),
        );
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Home',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          selectedIcon: Icon(Icons.receipt_long),
          label: 'Activity',
        ),
        NavigationDestination(
          icon: Icon(Icons.credit_score_outlined),
          selectedIcon: Icon(Icons.credit_score),
          label: 'Loans',
        ),
        NavigationDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          selectedIcon: Icon(Icons.account_balance_wallet),
          label: 'Accounts',
        ),
        NavigationDestination(
          icon: Icon(Icons.more_horiz),
          selectedIcon: Icon(Icons.more),
          label: 'More',
        ),
      ],
    );
  }

  Widget _screenForRoute(String route) {
    switch (route) {
      case '/transactions':
        return const TransactionListScreen();
      case '/loans':
        return const LoanListScreen();
      case '/accounts':
        return const AccountListScreen();
      case '/more':
        return const MoreScreen();
      case '/':
      default:
        return const DashboardScreen();
    }
  }
}
