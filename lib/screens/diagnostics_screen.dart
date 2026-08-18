import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../utils/amount_colors.dart';

// ponytail: diagnostics = sync history/error surface, no persisted app-wide error log yet.
class DiagnosticsScreen extends StatelessWidget {
  const DiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final syncProvider = context.watch<SyncProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Diagnostics & error log')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              leading: Icon(
                syncProvider.lastError != null
                    ? Icons.error_outline
                    : Icons.check_circle_outline,
                color: syncProvider.lastError != null
                    ? expenseColor(colorScheme)
                    : incomeColor(colorScheme),
              ),
              title: Text(
                syncProvider.lastError != null
                    ? 'Last sync error'
                    : 'No active errors',
              ),
              subtitle: Text(
                syncProvider.lastError ?? 'Everything looks fine.',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'SYNC HISTORY',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          if (syncProvider.syncHistory.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'No sync activity recorded yet.',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            )
          else
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  for (final item in syncProvider.syncHistory)
                    ListTile(
                      dense: true,
                      leading: Icon(
                        item['status'] == 'success'
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: item['status'] == 'success'
                            ? incomeColor(colorScheme)
                            : expenseColor(colorScheme),
                      ),
                      title: Text('${item['createdAt']}'),
                      subtitle: Text(
                        '${item['status']} · ${item['syncedCount']} rows${item['message'] != null ? ' · ${item['message']}' : ''}',
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
