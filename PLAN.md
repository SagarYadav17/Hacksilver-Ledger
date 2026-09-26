# Hacksilver Ledger delivery plan

The product is a single Expo/React Native application with a fresh SQLite
schema, optional PocketBase sync, tests, and documentation. There are no
production users or migration requirements yet; MCP is excluded from this
release.

## Current foundation

- Offline-first SQLite repository with seeded finance categories.
- Accounts, transactions, transfers, loans, recurring entries, analytics,
  backup/restore, app lock, notifications, and background sync.
- Optional authenticated PocketBase two-way sync with UUID sync IDs,
  tombstones, conflict history, and dependency-ordered pull/push.
- Repository tests, TypeScript checks, Oxlint, Oxfmt, and Expo web export in
  the local quality gate.

## Next product work

- Validate PocketBase sync against live collections on Android and iOS.
- Add device-level UI coverage for transaction, backup, and sync flows.
- Harden account reconciliation, loan reminders, and backup recovery UX.
- Prepare release signing, crash reporting, and production backup operations.

## Quality gates

```bash
bun run typecheck
bun run lint
bun run format:check
bun test
bunx expo export --platform web
```

Native release builds should be run from a clean generated Expo workspace
before distribution.
