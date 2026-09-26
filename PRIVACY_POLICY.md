# Privacy Policy for Hacksilver Ledger

Effective date: 26 September 2026

Hacksilver Ledger ("the app") is a personal finance app designed for local-first use. This policy explains what information the app stores, how it is used, and when it may leave your device.

## 1. Information the App Handles

You do not need to register to use the app's local features. The app stores the information you enter, which may include:

- Account names, types, and balances
- Transaction titles, amounts, dates, types, notes, and account/category links
- Categories
- Recurring transaction amounts, schedules, notes, and account/category links
- Loan amounts, interest rates, repayment details, notes, and payment history
- App preferences, such as currency and whether balances are hidden

Ledger records are stored in a local SQLite database on your device. App preferences, your optional app-lock PIN hash, and optional PocketBase connection/session information are stored using the device's secure storage facility.

If a sync conflict occurs, the app may store local and remote record snapshots in its local sync-conflict history to support conflict handling.

## 2. How Information Is Used

Information is used to provide app features, including summaries and reports, managing your ledger, applying your preferences, and creating or restoring backups.

Cloud sync is optional. If you configure a PocketBase server and sign in, the app sends the ledger records needed for sync to that server. This includes account balances; transaction, loan, recurring-entry, and category details; notes; dates; and links between records. The app also sends your email address and password to the configured server when you create an account or sign in. The app stores the resulting session information on your device; it does not use your PocketBase password as a ledger field.

After you sign in, you can sync manually. The app may also sync when a network connection becomes available and through operating-system background tasks. Background execution is best-effort and depends on the device and operating system.

## 3. Sharing and Disclosure

The app does not sell your information. The app does not automatically send your financial records to the developer.

If you enable sync, your information is sent to the PocketBase server URL you configure. That server may be self-hosted or operated by someone else. Its operator and hosting provider may be able to access server data and logs under their control. You are responsible for choosing a server you trust and reviewing its privacy and retention practices.

When you export a backup, the app creates a JSON file containing your ledger records and opens the device's share sheet. Any app, person, or storage service you choose there may receive a copy. The app does not control copies made or retained by those destinations.

When you restore, you choose a backup file through the device's file picker. The app reads that file to replace the local ledger data. The app does not send the selected file to the developer as part of the restore operation.

## 4. Permissions and Device Features

The app may use:

- Network access for optional PocketBase account access and sync
- Background-task scheduling for best-effort sync after you have configured and signed in to a server
- The system file picker to select a backup for restore
- The system share sheet to export a backup
- Notifications, if you request a loan reminder and grant notification permission

Loan reminder notifications include the loan title and that a payment is due tomorrow. Depending on your device settings, notification content may appear on the lock screen.

## 5. Third-Party Services and Libraries

The app uses third-party software libraries for local storage, secure storage, file selection, sharing, networking, notifications, and optional PocketBase sync. The app's sync destination is the PocketBase server URL you enter. The app's current source does not include an analytics or crash-reporting service integration.

The app does not require a cloud account for local use. Optional sync depends on the PocketBase server you choose; the server operator's practices are governed by that operator's policies and configuration.

## 6. Security

Ledger records are stored in the app's local SQLite database. The app uses the device's secure storage facility for selected preferences, the app-lock PIN hash, and PocketBase session information. The app-lock PIN is stored as a hash; it is a convenience feature and should not be treated as a substitute for your device's screen lock.

Exported backups are JSON files and are not encrypted by the app. The share destination determines how shared copies are handled. Network protection for optional sync depends on the URL and security configuration of the PocketBase server you choose; use a trusted server configured for HTTPS.

## 7. Retention and Deletion

Local ledger data remains on your device until it is removed, app data is cleared, or the app is uninstalled. Some record deletions are represented by sync tombstones rather than immediate erasure. A tombstone can remain in the local database and be sent to your configured PocketBase server so the deletion can be synchronized with other devices.

The app does not currently provide a control to erase your PocketBase account and all data stored on that server. Server-side copies, including sync tombstones, may remain until they are removed by the server operator. Contact the operator of your configured server about server-side deletion and retention. Copies of exported backups remain wherever you or a share destination stored them, subject to that destination's retention practices.

## 8. Children's Privacy

The app is not designed for children under 13 and does not include age verification. If you believe a child has created an optional PocketBase account, contact the operator of the configured server about that account and its data.

## 9. Changes to This Policy

This policy may be updated as the app changes. The effective date at the top of this document will be revised when the policy is updated.

## 10. Contact

For privacy questions about the app, contact the developer through the project repository:

- GitHub: https://github.com/SagarYadav17/Hacksilver-Ledger
- Issues: https://github.com/SagarYadav17/Hacksilver-Ledger/issues
