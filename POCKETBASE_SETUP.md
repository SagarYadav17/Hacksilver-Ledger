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
- Update: `user = @request.auth.id`
- Delete: `user = @request.auth.id`

Leave `users` at PocketBase defaults, or disable open signup there if you
invite users yourself.

## 4. Connect app

In the app, open **Sync & backup**, select **Device + cloud copy**, enter the
server URL (for example `https://pb.example.com`), then sign up or log in.

During current development, clear/reinstall the app and reset development
collections after a local schema change. Do not test two-way behavior against
old remote rows created with numeric relation fields.

## 5. Sync behavior

Manual sync uploads local changes. The release target adds two-way pull,
newest-UTC-change wins conflict handling, tombstones, sync history, and
background retry. Until that lands, cloud copy remains upload-only.
