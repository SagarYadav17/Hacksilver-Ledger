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
import 'screens/more_screen.dart';
import 'screens/sync_backup_screen.dart';
import 'screens/diagnostics_screen.dart';
import 'screens/analytics_screen.dart';
import 'providers/theme_provider.dart';
import 'providers/loan_provider.dart';
import 'providers/currency_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/security_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/loan_list_screen.dart';
import 'screens/add_loan_screen.dart';
import 'screens/account_list_screen.dart';
import 'screens/add_account_screen.dart';
import 'screens/app_lock_screen.dart';

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
      textTheme: textTheme
          .copyWith(
            titleLarge: textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            titleMedium: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            labelLarge: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          )
          .apply(
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
      cardTheme: CardThemeData(
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
        fillColor: colorScheme.surfaceContainerHighest.withValues(
          alpha: brightness == Brightness.light ? 0.5 : 0.2,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surface,
        indicatorColor: colorScheme.secondaryContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
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
        ChangeNotifierProvider(create: (_) => SecurityProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()..initialize()),
        ChangeNotifierProxyProvider<AuthProvider, SyncProvider>(
          create: (_) => SyncProvider(),
          update: (_, auth, previous) =>
              (previous ?? SyncProvider())..bindAuth(auth),
        ),
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
            builder: (context, child) {
              return Consumer<SecurityProvider>(
                builder: (context, securityProvider, _) {
                  if (securityProvider.isLoading) {
                    return const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (securityProvider.shouldShowLock) {
                    return const AppLockScreen();
                  }
                  return child ?? const DashboardScreen();
                },
              );
            },
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
              '/more': (context) => const MoreScreen(),
              '/sync-backup': (context) => const SyncBackupScreen(),
              '/diagnostics': (context) => const DiagnosticsScreen(),
              '/analytics': (context) => const AnalyticsScreen(),
            },
          );
        },
      ),
    );
  }
}
