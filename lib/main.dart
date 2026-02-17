import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/database_service.dart';
import 'providers/transaction_provider.dart';
import 'providers/category_provider.dart';
import 'providers/account_provider.dart';
import 'providers/recurring_transaction_provider.dart';
import 'screens/dashboard_screen.dart';
import 'screens/transaction_list_screen.dart';
import 'screens/add_transaction_screen.dart';
import 'screens/category_list_screen.dart';
import 'screens/recurring_transaction_list_screen.dart';
import 'screens/add_recurring_transaction_screen.dart';
import 'screens/settings_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/currency_provider.dart';
import 'screens/loan_list_screen.dart';
import 'screens/add_loan_screen.dart';
import 'screens/account_list_screen.dart';
import 'screens/add_account_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildTheme({
    required Brightness brightness,
    required Color seedColor,
  }) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
    );
    final colorScheme = base.colorScheme;
    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme);

    return base.copyWith(
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: textTheme.copyWith(
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
        ),
        titleMedium: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ).apply(
        bodyColor: colorScheme.onSurface,
        displayColor: colorScheme.onSurface,
      ),
      iconTheme: IconThemeData(color: colorScheme.onSurfaceVariant),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardTheme(
        color: colorScheme.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minLeadingWidth: 40,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      navigationDrawerTheme: NavigationDrawerThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceVariant.withOpacity(
          brightness == Brightness.light ? 0.5 : 0.2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      chipTheme: base.chipTheme.copyWith(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 24,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<DatabaseService>(create: (_) => DatabaseService()),
        ChangeNotifierProvider(
          create: (_) => TransactionProvider()..fetchTransactions(),
        ),
        ChangeNotifierProvider(
          create: (_) => CategoryProvider()..initCategories(),
        ),
        ChangeNotifierProvider(
          create: (_) => AccountProvider()..initAccounts(),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              RecurringTransactionProvider()
                ..checkAndGenerateRecurringTransactions(),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProxyProvider<DatabaseService, LoanProvider>(
          create: (_) => LoanProvider(DatabaseService()),
          update: (_, db, previous) => previous ?? LoanProvider(db),
        ),
        ChangeNotifierProvider(create: (_) => CurrencyProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Hacksilver Ledger',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(
              brightness: Brightness.light,
              seedColor: themeProvider.seedColor,
            ),
            darkTheme: _buildTheme(
              brightness: Brightness.dark,
              seedColor: themeProvider.seedColor,
            ),
            themeMode: themeProvider.themeMode,
            initialRoute: '/',
            routes: {
              '/': (context) => const DashboardScreen(),
              '/transactions': (context) => const TransactionListScreen(),
              '/add-transaction': (context) => const AddTransactionScreen(),
              '/categories': (context) => const CategoryListScreen(),
              '/recurring-transactions': (context) =>
                  const RecurringTransactionListScreen(),
              '/add-recurring-transaction': (context) =>
                  const AddRecurringTransactionScreen(),
              '/loans': (context) => const LoanListScreen(),
              '/add-loan': (context) => const AddLoanScreen(),
              '/accounts': (context) => const AccountListScreen(),
              '/add-account': (context) => const AddAccountScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
