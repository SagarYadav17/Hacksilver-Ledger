# PocketBase sync reference

Hacksilver Ledger uses optional self-hosted PocketBase sync. SQLite remains
the offline source of truth; the mobile app never receives a PocketBase admin
credential.

Create these Base collections: `categories`, `accounts`, `loans`,
`recurring_transactions`, and `transactions`.

Every collection requires `user` (single required relation to `users`),
`local_sync_id` (required UUID text), `updated_at` (required UTC ISO-8601
text), and optional `deleted_at` (UTC tombstone text). Add a unique index on
`(user, local_sync_id)`.

Use text `*_sync_id` fields for cross-record references. Do not send SQLite
numeric IDs to PocketBase:

- `recurring_transactions`: `category_sync_id`, `account_sync_id`
- `transactions`: `category_sync_id`, `account_sync_id`,
  `transfer_account_sync_id`, `loan_sync_id`, `recurring_sync_id`

Apply the same collection rules everywhere:

- List/View: `user = @request.auth.id`
- Create: `@request.auth.id != "" && @request.body.user = @request.auth.id`
- Update/Delete: `user = @request.auth.id`

Sync pushes local pending changes, then pulls remote rows in dependency order:
categories, accounts, loans, recurring transactions, transactions. Tombstones
are retained. For simultaneous edits, newest UTC `updated_at` wins; the local
loser remains pending for retry.

Development database and PocketBase collection state are disposable. Clear app
data and reset development collections after changing the sync schema. Full
field definitions and server setup: [POCKETBASE_SETUP.md](../POCKETBASE_SETUP.md).
