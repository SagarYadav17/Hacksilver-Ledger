/// Base mixin for models that support sync
import 'package:uuid/uuid.dart';

enum SyncStatus { pending, synced, failed, conflict }

mixin SyncableModel {
  String? get syncId;
  DateTime? get updatedAt;
  DateTime? get deletedAt;
  SyncStatus get syncStatus;

  Map<String, dynamic> toSyncMap();
}

/// Utility to generate UUIDs for sync
const _uuid = Uuid();

String generateSyncId() => _uuid.v4();

/// Extension to convert SyncStatus to string
extension SyncStatusExtension on SyncStatus {
  String toValue() {
    switch (this) {
      case SyncStatus.pending:
        return 'pending';
      case SyncStatus.synced:
        return 'synced';
      case SyncStatus.failed:
        return 'failed';
      case SyncStatus.conflict:
        return 'conflict';
    }
  }

  static SyncStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return SyncStatus.pending;
      case 'synced':
        return SyncStatus.synced;
      case 'failed':
        return SyncStatus.failed;
      case 'conflict':
        return SyncStatus.conflict;
      default:
        return SyncStatus.pending;
    }
  }
}
