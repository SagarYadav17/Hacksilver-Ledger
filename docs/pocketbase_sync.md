# PocketBase sync reference

Hacksilver Ledger uses optional self-hosted PocketBase sync. SQLite remains
the offline source of truth; the app never receives a PocketBase admin
credential.

Create these Base collections: `categories`, `accounts`, `loans`,
`recurring_transactions`, and `transactions`.

Every collection requires `user` (single required relation to `users`),
`local_sync_id` (required UUID text), `updated_at` (required UTC ISO-8601
text), optional `deleted_at` (UTC tombstone text), and the `created`/`updated`
autodate fields (default for Admin UI collections in v0.23+). Add a unique index on
`(user, local_sync_id)`.

Use text `*_sync_id` fields for cross-record references. Do not send SQLite
numeric IDs to PocketBase:

- `recurring_transactions`: `category_sync_id`, `account_sync_id`
- `transactions`: `category_sync_id`, `account_sync_id`,
  `transfer_account_sync_id`, `loan_sync_id`, `recurring_sync_id`

Apply the same collection rules everywhere:

- List/View: `user = @request.auth.id`
- Create: `@request.auth.id != "" && @request.body.user = @request.auth.id`
- Update: `user = @request.auth.id && (@request.body.user:isset = false || @request.body.user = @request.auth.id)`
  (stops a user from reassigning a record to another account)
- Delete: `user = @request.auth.id`

The app requires `https://` server URLs except for local development hosts
(`localhost`, `127.0.0.1`, `[::1]`, `10.0.2.2`, `*.localhost`).

Sync is incremental and runs one at a time. It pushes local rows changed since
the last successful sync (cursor = sync start time), then pulls remote rows
whose server-set `updated` is at or after the newest one previously seen for
that collection, in dependency order: categories, accounts, loans, recurring
transactions, transactions. Remote records are
schema-validated; bad or unappliable records are skipped, counted in the result
message, and retried next sync. Tombstones are retained. For simultaneous
edits, newest UTC `updated_at` wins and local wins are logged in
`sync_conflicts`.

Development database and PocketBase collection state are disposable. Clear app
data and reset development collections after changing the sync schema. Full
field definitions and server setup: [POCKETBASE_SETUP.md](../POCKETBASE_SETUP.md).
