# PocketBase server setup

Hacksilver Ledger uses an optional self-hosted
[PocketBase](https://pocketbase.io) instance. SQLite remains local source of
truth. PocketBase never receives a server-admin credential from the app.

## 1. Run PocketBase

Download the PocketBase binary, then run:

```text
./pocketbase serve
```

Open `http://127.0.0.1:8090/_/` and create an admin account. The built-in
`users` auth collection handles app signup/login without changes.

## 2. Create collections

Create five **Base** collections named exactly: `categories`, `accounts`,
`transactions`, `loans`, and `recurring_transactions`.

Every collection needs:

| Field | Type | Rule |
|---|---|---|
| `user` | Relation to `users` | Required, one record |
| `local_sync_id` | Text | Required UUID |
| `updated_at` | Text | Required UTC ISO-8601 timestamp |
| `deleted_at` | Text | Optional UTC ISO-8601 tombstone timestamp |

Every collection must also have PocketBase's `created` and `updated`
**Autodate** fields (`updated` set on create and update). Collections created
in the Admin UI on PocketBase v0.23+ get them by default; add them yourself if
you created a collection by import/API without them. The app pulls by the
server-set `updated` value, so sync misses changes without it.

Add a unique index on `(user, local_sync_id)` in every collection. These UUIDs
are stable across devices; never create relations with SQLite numeric IDs.

### Categories

`name` (text), `icon_code` (number), `font_family` (text, optional),
`font_package` (text, optional), `color_value` (number), `type` (text),
`is_custom` (bool), `sort_order` (number), `is_archived` (bool).

### Accounts

`name` (text), `type` (text), `balance` (number).

### Loans

`title` (text), `amount` (number), `interest_rate` (number),
`tenure_months` (number), `type` (text), `start_date` (text),
`emi_amount` (number), `amount_paid` (number), `is_closed` (bool), `notes`
(text, optional).

### Recurring transactions

`title` (text), `amount` (number), `type` (text), `frequency` (text),
`start_date` (text), `next_due_date` (text), `is_active` (bool), `notes`
(text, optional), `category_sync_id` (text), `account_sync_id` (text,
optional).

### Transactions

`title` (text), `amount` (number), `date` (text), `type` (text), `notes`
(text, optional), `original_amount` (number, optional), `original_currency`
(text, optional), `category_sync_id` (text), `account_sync_id` (text,
optional), `transfer_account_sync_id` (text, optional), `loan_sync_id` (text,
optional), `recurring_sync_id` (text, optional).

Each `*_sync_id` points to another record's `local_sync_id` owned by the same
user. Create these as text fields, not PocketBase relation fields: collection
rules cannot safely enforce ownership through a relation traversal.

## 3. API rules

Set these rules on every synced collection:

- List/Search: `user = @request.auth.id`
- View: `user = @request.auth.id`
- Create: `@request.auth.id != "" && @request.body.user = @request.auth.id`
- Update: `user = @request.auth.id && (@request.body.user:isset = false || @request.body.user = @request.auth.id)`
- Delete: `user = @request.auth.id`

The Update rule stops a signed-in user from reassigning one of their records
to another account by sending a different `user` value.

Leave `users` at PocketBase defaults, or disable open signup there if you
invite users yourself.

## 4. Connect app

In the app, open **Sync & backup**, select **Device + cloud copy**, enter the
server URL (for example `https://pb.example.com`), then sign up or log in.

The app requires `https://` for every server except local development hosts:
`localhost`, `127.0.0.1`, `[::1]`, `10.0.2.2` (Android emulator), and names
ending in `.localhost`. Put PocketBase behind a TLS-terminating reverse proxy
(Caddy, nginx, etc.) for LAN or internet use.

During current development, clear/reinstall the app and reset development
collections after a local schema change. Do not test two-way behavior against
old remote rows created with numeric relation fields.

## 5. Sync behavior

The React Native client performs incremental two-way sync in dependency order:
categories, accounts, loans, recurring transactions, then transactions.

- Only one sync runs at a time; concurrent triggers share the running sync.
- Push sends local rows with `updated_at` after the last successful sync
  (everything on first sync). Existing remote records are looked up in batches
  of 50 `local_sync_id`s.
- Pull fetches remote records whose server-set `updated` is at or after the
  newest `updated` seen in the previous pull, per collection. Using the
  server clock means an edit made offline on another device, and pushed later,
  is still pulled. Re-fetched boundary records are skipped as unchanged.
- The push cursor is set to the time the sync *started*, so local edits made
  during a sync are pushed next time.
- Each remote record is validated before it is applied. Invalid records, or
  records that fail locally (for example a missing parent), are skipped and
  counted ("N remote records failed to apply"); the sync still succeeds, but
  that collection's pull cursor is not advanced so they are retried next time.
- Tombstones are retained, newest UTC `updated_at` wins, and local-wins
  conflicts are recorded in `sync_conflicts`.
- The saved session is refreshed on app start. A rejected token signs the user
  out; a network failure keeps the still-valid token.
- Background retry is registered where the operating system permits it. The server remains optional and local SQLite
continues to be the source of truth.
