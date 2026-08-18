import 'package:flutter_test/flutter_test.dart';
import 'package:hacksilver_ledger/models/sync_model.dart';
import 'package:hacksilver_ledger/services/database_service.dart';

void main() {
  test('generated sync IDs are unique UUIDs', () {
    final first = generateSyncId();
    final second = generateSyncId();
    final uuid = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
    );

    expect(first, matches(uuid));
    expect(second, matches(uuid));
    expect(first, isNot(second));
  });

  test('sync status uses safe persistence values', () {
    expect(SyncStatusExtension.fromValue('conflict'), SyncStatus.conflict);
    expect(SyncStatusExtension.fromValue('unknown'), SyncStatus.pending);
  });

  test('latest UTC update wins conflicts', () {
    final local = DateTime.parse('2026-08-18T12:00:00+05:30');

    expect(
      shouldApplyRemote(local, DateTime.parse('2026-08-18T06:29:59Z')),
      isFalse,
    );
    expect(
      shouldApplyRemote(local, DateTime.parse('2026-08-18T06:30:00Z')),
      isTrue,
    );
    expect(
      shouldApplyRemote(local, DateTime.parse('2026-08-18T06:30:01Z')),
      isTrue,
    );
  });
}
