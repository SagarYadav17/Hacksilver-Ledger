# Android major release: rebuild ledger + complete PocketBase sync

## Summary

No production users or data. Rebuild SQLite schema from scratch; no backward migrations, compatibility paths, or data preservation. Ship one Android release with complete finance UX, reliable two-way PocketBase sync, tests, docs. MCP excluded.

## Implementation

- Development reset:
  - Replace existing SQLite creation schema with final tables/columns and seed rows.
  - Remove `onUpgrade` migration code. Keep one schema version for fresh creation only.
  - Require clearing app data/reinstalling before local testing; reset PocketBase development collections before sync integration tests.
  - Revert planning-tool changes in `analysis_options.yaml`, `pubspec.lock`, Windows generated plugin files. Fix existing `onReorder` deprecation.
- Data/sync:
  - Add sync metadata, durable sync history, tombstones, and UUID sync IDs in fresh schema.
  - Use sync-ID references for transaction category/account/loan/recurring relationships; never sync device-local numeric IDs as cross-device relations.
  - Push then pull categories/accounts, loans, recurring rules, transactions. Paginate authenticated PocketBase records.
  - Apply newest UTC `updated_at` on conflicts; record outcome/error in sync history.
  - Soft-delete records, sync tombstones, hide deleted records in app.
  - Add Android WorkManager sync: authenticated users only, network required, six-hour schedule, exponential retry. Preserve immediate manual sync.
  - Update PocketBase collections/rules guide for new fields and behavior.
- Product UX:
  - Use Mobbin research before each major UX slice: transactions, accounts,
    loans, categories, recurring items, and backup. Reuse interaction patterns
    only; do not copy branded assets or layouts. Keep Material 3 and
    local-first navigation.
  - Add transaction sorting; preserve search, transfer filter, details, edit/delete.
  - Add period comparison to analytics.
  - Add account details, history, trend, reconciliation adjustment.
  - Add loan repayment calendar/reminders.
  - Add category reorder/archive/merge with transaction reassignment.
  - Add recurring edit controls; retain pause/resume.
  - Add backup history, restore confirmation, integrity status, recovery-copy visibility.
- Documentation:
  - Make README, feature map, setup guide, and app labels PocketBase-correct.
  - Record development-reset requirement and Android release workflow.
  - Mark completed UX work accurately. Keep MCP/FastAPI as separate future roadmap.

## Parallel implementation agents

- Agent 1: fresh SQLite schema, models, PocketBase push/pull/conflicts, unit tests.
- Agent 2: finance UX and widget tests.
- Agent 3: Android background sync, backup history/safety, docs, integration harness.
- Primary agent: lock shared contracts, resolve conflicts, review all changes, run quality gates.

## Public interfaces

- `SyncProvider`: sync phase, last pull, conflict count, retry/error state.
- `SyncService`: push/pull result with per-table counts and conflict details.
- Backup service/UI: backup metadata, restore result, recovery-copy path.
- PocketBase collections: `user`, `local_sync_id`, UTC timestamps, tombstones, sync-ID relation fields.

## Test and release gates

- Unit: balances, loan payments, recurring generation, sync mapping, conflict winner, tombstones, retries.
- Widget: sort/filter, balance hiding, category merge/archive, recurring edit/pause, backup restore, sync status/errors.
- Android integration: fresh install; offline CRUD; backup/restore; signup/login; two-device sync; conflict; deletion; network retry; background sync.
- Gates: clean `flutter analyze`, `flutter test`, Android integration suite, release APK/AAB build, PocketBase user-isolation check.

## Assumptions

- Destructive reset acceptable until release; no migration support.
- PocketBase remains sole backend.
- Newest UTC change wins; no manual conflict screen.
- Android release only; Flutter code stays portable.
- MCP/FastAPI excluded.
