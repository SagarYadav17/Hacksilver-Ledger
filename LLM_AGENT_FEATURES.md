# Hacksilver Ledger: UI Feature Map for LLM Agents

This document is for UI planning. It separates features already present in app from features desired next, so new screens and flows can be designed against real product state.

## Goal

Design a cleaner, more capable finance app UI without losing current offline-first behavior. Treat this as product truth for layout, navigation, empty states, settings, and future expansion.

## Features Available Now

### Dashboard
- Financial summary card with available balance, current-month income, and current-month expense
- Recent transactions preview
- Manual refresh action
- Empty state with add-transaction CTA

### Transactions
- Add transaction
- Edit transaction
- Delete transaction
- Support for income, expense, and transfer entries
- Date picker
- Optional notes
- Optional foreign-currency amount and original currency
- Filter by type: income, expense
- Filter by date range

### Categories
- Built-in default categories
- Custom categories
- Custom category icon
- Custom category color
- Separate income and expense category views

### Accounts
- Multiple accounts
- Account types: cash, bank, credit card, other
- Add, edit, delete account
- Automatic account balance updates after income, expense, and transfer activity

### Recurring Transactions
- Add recurring transaction
- List recurring transactions
- Delete recurring transaction
- Automatic transaction generation when due

### Loans
- Track taken loans and given loans
- Add, edit, delete loan
- EMI/payment entry flow
- Loan-linked transactions
- Loan history screen
- Progress tracking with paid vs remaining amount
- Closed vs active state

### Appearance and Preferences
- Material 3 theming
- Light mode
- Dark mode
- System theme
- Accent color selection
- Currency selection: INR, USD, EUR, GBP
- Navigation drawer routing across major sections

### Backup and Sync
- Local database backup export
- Local database restore
- Supabase credential setup
- Manual one-way sync from local database to Supabase
- Pending sync count
- Last sync timestamp
- Sync error display

## Features Wanted Next

### Better Transaction UX
- Transfer filter in transaction list
- Richer search and sort
- Transaction details sheet instead of only edit flow
- Faster add flow with presets, templates, and recent selections
- Better recurring transaction editing and pause/resume controls

### Better Dashboard UX
- Chart-based analytics
- Spending by category
- Monthly trend views
- Cashflow comparison periods
- Quick actions always visible, not only empty state

### Better Loan UX
- Dedicated EMI timeline
- Repayment calendar
- Loan insights and reminders
- Better distinction between borrowings and lendings

### Better Account UX
- Account details page
- Transfer-focused UI
- Account health, trends, and reconciliation states

### Better Category UX
- Category usage stats
- Reorder, merge, and archive categories
- Better icon and color picker UX

### Sync and Cloud
- Clear local/cloud/hybrid mode UI
- Background sync status
- Conflict handling UI
- Sync history and audit log
- Better onboarding for Supabase setup

### Safety and Utility
- App lock / PIN UX
- Better backup history UI
- Restore confirmation flow
- Error recovery and diagnostics screens

## UI Design Notes

- App is offline-first. Cloud must feel optional, not required.
- Current navigation is drawer-based. New UI can improve this, but must preserve access to dashboard, transactions, categories, recurring items, loans, accounts, and settings.
- Current feature set is strong in CRUD and weak in analytics. New UI should highlight existing core workflows first, then make room for planned insights.
- Current sync exists but is still early-stage. UI should present it as advanced/optional, not as primary product path.
