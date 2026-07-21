# PocketBase server setup

Hacksilver Ledger backs up to a self-hosted [PocketBase](https://pocketbase.io)
instance. The app never ships or manages the server — you run PocketBase
yourself and create the collections below once. Each app install then signs
up or logs in with its own PocketBase account, and every synced row is scoped
to that account via API rules, so multiple people can share one server
without seeing each other's data.

## 1. Run PocketBase

Download the single binary for your platform from
https://pocketbase.io/docs/ and run:

```
./pocketbase serve
```

Open the admin UI at `http://127.0.0.1:8090/_/` and create an admin account.
The built-in `users` auth collection is used as-is for login/signup — no
changes needed there.

## 2. Create the synced collections

Create five collections, all **Base** type (not Auth), named exactly:
`categories`, `accounts`, `transactions`, `loans`, `recurring_transactions`.

Every collection needs these two fields in addition to its own data fields:

| Field | Type | Notes |
|---|---|---|
| `user` | Relation → `users` | Required, single record |
| `local_sync_id` | Text | Required — the app's locally-generated UUID for this row |

Add a **unique index** on (`user`, `local_sync_id`) for each collection so a
device can never create two remote rows for the same local record.

### `categories` fields
`local_id` (number), `name` (text), `icon_code` (number), `font_family`
(text, optional), `font_package` (text, optional), `color_value` (number),
`type` (text), `is_custom` (bool), `updated_at` (text), `deleted_at` (text,
optional)

### `accounts` fields
`local_id` (number), `name` (text), `type` (text), `balance` (number),
`updated_at` (text), `deleted_at` (text, optional)

### `transactions` fields
`local_id` (number), `title` (text), `amount` (number), `date` (text), `type`
(text), `category_id` (number), `account_id` (number, optional),
`transfer_account_id` (number, optional), `notes` (text, optional),
`original_amount` (number, optional), `original_currency` (text, optional),
`loan_id` (number, optional), `recurring_id` (number, optional), `updated_at`
(text), `deleted_at` (text, optional)

### `loans` fields
`local_id` (number), `title` (text), `amount` (number), `interest_rate`
(number), `tenure_months` (number), `type` (text), `start_date` (text),
`emi_amount` (number), `amount_paid` (number), `is_closed` (bool), `notes`
(text, optional), `updated_at` (text), `deleted_at` (text, optional)

### `recurring_transactions` fields
`local_id` (number), `title` (text), `amount` (number), `type` (text),
`category_id` (number), `account_id` (number, optional), `frequency` (text),
`start_date` (text), `next_due_date` (text), `is_active` (bool), `notes`
(text, optional), `updated_at` (text), `deleted_at` (text, optional)

## 3. API rules (this is what isolates each user's data)

Set the same four rules on **every** one of the five collections:

- **List/Search rule**: `user = @request.auth.id`
- **View rule**: `user = @request.auth.id`
- **Create rule**: `@request.auth.id != "" && @request.body.user = @request.auth.id`
- **Update rule**: `user = @request.auth.id`
- **Delete rule**: `user = @request.auth.id`

Leave the `users` collection's own rules at PocketBase's defaults (or disable
open signups there if you want to invite people manually instead of letting
anyone self-register).

## 4. Point the app at your server

In the app: More → Sync & backup → "Device + cloud copy" → enter your
server's URL (e.g. `https://pb.your-domain.com`) → sign up or log in. From
then on, "Sync now" uploads pending local changes; each row lands in the
collection matching its type, tagged with your account so no other user on
the same server can read or write it.
