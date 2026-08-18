# Hacksilver Ledger

Offline-first personal finance app built with Flutter. SQLite is source of
truth on each device; PocketBase is optional, self-hosted cloud storage.

## Current capabilities

- Accounts, income, expenses, transfers, categories, recurring transactions,
  loans, EMI-linked payments, and local backup/restore.
- Material 3 light, dark, and system themes; currency selection; optional PIN
  lock and balance hiding.
- Transaction search, type/date filters, details, edit, and delete.
- Analytics for income, expenses, savings rate, trends, and category spend.
- Optional PocketBase login and manual one-way cloud copy. Sessions use secure
  storage; each remote record belongs to its authenticated PocketBase user.

## Release work in progress

Android release work upgrades cloud copy to two-way PocketBase sync, adds
sync-ID relations, tombstones, conflict history, background retry, safer
backup history, and remaining account/loan/category/recurring UX. Until that
work lands, cloud copy is upload-only; it is not multi-device sync.

This app is still in development. Local schema changes are destructive: clear
app data or reinstall before testing a new build. Do not rely on development
data surviving an update.

## Stack

- Flutter + Material 3
- Provider
- SQLite (`sqflite`)
- PocketBase client (optional sync)
- `flutter_secure_storage` for PIN hash and PocketBase session

## Run

```bash
flutter pub get
flutter run
```

For PocketBase setup and collection rules, see
[POCKETBASE_SETUP.md](POCKETBASE_SETUP.md).

## Quality checks

```bash
flutter analyze
flutter test
flutter build appbundle --release
```

## Roadmap

- Finish reliable two-way PocketBase sync and Android background work.
- Finish account details/reconciliation, loan timelines/reminders, category
  merge/archive, recurring editing, and backup recovery history.
- FastAPI/MCP is intentionally out of this release.
