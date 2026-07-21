import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/sync_provider.dart';
import '../providers/auth_provider.dart';
import '../services/backup_service.dart';
import 'auth_screen.dart';

class SyncBackupScreen extends StatelessWidget {
  const SyncBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Sync & backup')),
      body: Consumer2<SyncProvider, AuthProvider>(
        builder: (context, syncProvider, authProvider, child) {
          final loggedIn = authProvider.isLoggedIn;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _sectionLabel(context, 'WHERE YOUR DATA LIVES'),
              const SizedBox(height: 12),
              _ModeCard(
                icon: Icons.smartphone_outlined,
                title: 'On this device',
                subtitle: 'Fully offline. Nothing leaves your phone.',
                selected: !loggedIn,
                onTap: loggedIn
                    ? () => _showLogoutDialog(context, authProvider)
                    : null,
              ),
              const SizedBox(height: 12),
              _ModeCard(
                icon: Icons.cloud_outlined,
                title: 'Device + cloud copy',
                subtitle: loggedIn
                    ? 'Backing up to ${authProvider.currentEmail ?? 'your account'}'
                    : 'One-way backup to your self-hosted PocketBase server.',
                selected: loggedIn,
                onTap: loggedIn
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AuthScreen()),
                      ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: 0.6,
                child: _ModeCard(
                  icon: Icons.sync_outlined,
                  title: 'Two-way sync — coming soon',
                  subtitle: 'Keep multiple devices in sync automatically.',
                  selected: false,
                  onTap: null,
                ),
              ),
              if (loggedIn) ...[
                const SizedBox(height: 28),
                _sectionLabel(context, 'CLOUD COPY STATUS'),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.4,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(
                          Icons.cloud_done_outlined,
                          color: colorScheme.primary,
                        ),
                        title: Text(
                          syncProvider.pendingCount > 0
                              ? 'Backed up · ${syncProvider.pendingCount} entries pending'
                              : 'Backed up · up to date',
                        ),
                        subtitle: Text(
                          syncProvider.lastSyncAt != null
                              ? 'Last sync ${_formatDateTime(syncProvider.lastSyncAt!)}'
                              : 'Never synced',
                        ),
                        trailing: syncProvider.isSyncing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : FilledButton(
                                onPressed: () =>
                                    _performSync(context, syncProvider),
                                child: const Text('Sync now'),
                              ),
                      ),
                      if (syncProvider.lastError != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              syncProvider.lastError!,
                              style: TextStyle(
                                color: colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ),
                      if (syncProvider.syncHistory.isNotEmpty) ...[
                        Divider(color: colorScheme.outlineVariant, height: 1),
                        for (final item in syncProvider.syncHistory)
                          ListTile(
                            dense: true,
                            leading: Icon(
                              item['status'] == 'success'
                                  ? Icons.check_circle_outline
                                  : Icons.error_outline,
                              color: item['status'] == 'success'
                                  ? colorScheme.primary
                                  : colorScheme.error,
                            ),
                            title: Text(
                              item['status'] == 'success'
                                  ? '${item['syncedCount']} rows · ok'
                                  : 'Sync failed',
                            ),
                            subtitle: Text(
                              _syncHistorySubtitle(item),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      Divider(color: colorScheme.outlineVariant, height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.logout_outlined,
                          color: colorScheme.error,
                        ),
                        title: Text(
                          'Log out',
                          style: TextStyle(color: colorScheme.error),
                        ),
                        subtitle: const Text(
                          'Stop backing up from this device',
                        ),
                        onTap: () => _showLogoutDialog(context, authProvider),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 28),
              _sectionLabel(context, 'LOCAL BACKUP'),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('Export file'),
                      onPressed: () async {
                        await BackupService().exportDatabase(context);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.upload_outlined),
                      label: const Text('Restore…'),
                      onPressed: () => _showRestoreDialog(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Restore always asks before replacing data on this device.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
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

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} hours ago';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  String _syncHistorySubtitle(Map<String, dynamic> item) {
    final createdAt = DateTime.tryParse('${item['createdAt']}');
    final time = createdAt != null
        ? _formatDateTime(createdAt)
        : 'unknown time';
    final message = item['message'] as String?;
    if (message == null || message.isEmpty || item['status'] == 'success') {
      return time;
    }
    return '$time • $message';
  }

  Future<void> _showRestoreDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore database'),
        content: const Text(
          'This will overwrite your current data. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await BackupService().restoreDatabase(context);
            },
            child: const Text('Restore'),
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Sync complete! ${result.syncedCount} items uploaded.'
              : result.errorMessage ?? 'Sync failed',
        ),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _showLogoutDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text(
          'This device will stop backing up to the cloud. Your local data will remain intact.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await authProvider.logOut();
              if (!context.mounted) return;
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Logged out')));
            },
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  const _ModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? colorScheme.primary : colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                icon,
                color: selected
                    ? colorScheme.primary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'CURRENT',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: colorScheme.onSecondaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
