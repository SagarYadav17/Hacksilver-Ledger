# Hacksilver Ledger: UI feature map

Use this document for UI work. Preserve offline-first finance flows; PocketBase
is optional and must never block local use.

## Available now

### Core finance

- Dashboard with balance, current-month income/expense, recent activity, and
  add-transaction empty state.
- Income, expense, and transfer CRUD; date range/type filters, search, notes,
  foreign-currency amount, transaction detail sheet.
- Custom and default categories, icons/colors, category archive/reorder.
- Multiple accounts with automatic balances after transactions/transfers.
- Recurring transactions with due generation and active/inactive toggle.
- Taken/given loans, EMI/payment entries, loan history, paid/remaining state.

### Preferences and safety

- Material 3 themes, accent colors, INR/USD/EUR/GBP, navigation drawer.
- PIN lock and balance hiding.
- Local database export/restore with confirmation.

### Cloud

- Optional PocketBase server URL, sign-up/login, secure session storage.
- Manual local-to-PocketBase cloud copy, pending count, last-sync time, and
  sync error/history display.
- Current cloud copy is one-way. Do not describe it as backup recovery or
  multi-device sync.

## Release work in progress

### Sync and backup

- Two-way PocketBase sync with authenticated user isolation, UUID sync IDs,
  tombstones, conflict history, retry, and Android background scheduling.
- Backup history, integrity result, recovery-copy visibility, and restore
  safety.

### Finance UX

- Persistent transaction sort controls.
- Analytics period comparison and resilient empty states.
- Account details, history, trend, reconciliation adjustment.
- Loan repayment timeline/calendar and reminders.
- Category merge with reassignment confirmation and usage stats.
- Recurring transaction editing and clearer pause/resume controls.

## Design rules

- Local data remains usable offline. Cloud controls stay secondary and explain
  their state plainly.
- Preserve access to dashboard, transactions, categories, recurring items,
  loans, accounts, analytics, and settings.
- Before a new flow, use Mobbin to study finance-app information hierarchy,
  empty states, confirmation patterns, and compact mobile forms; do not copy
  branded assets or layouts.
- Treat balances and loan figures as sensitive: respect balance hiding and use
  clear destructive-action confirmation.
