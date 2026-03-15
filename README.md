# Hacksilver Ledger

A comprehensive Personal Finance Management application built with Flutter. This app helps you track your income, expenses, loans, and transfers across multiple accounts, giving you a clear picture of your financial health.

## 🌟 Key Features

### 📊 Dashboard & Analytics

- **Financial Overview**: Real-time summary of Total Balance, Income, and Expenses.
- **Visual Summary**: Color-coded and icon-based representation of financial data.
- **Quick Actions**: Easily refresh data or add new transactions from the dashboard.

### 🎨 Customization & Design

- **Material Design 3**: Fully compliant with Android's modern design language.
- **Dynamic Themes**: Choose your realm's accent color from **Slate** (Blue-Grey), **Frost** (Cyan), **Spartan** (Red), **Forest** (Teal), **Gold** (Amber), **Mystic** (Purple), and **Earth** (Brown).
- **Navigation Drawer**: Persistent lateral navigation for quick access to all sections.
- **Dark/Light Mode**: Full support for system, light, and dark themes.

### 💰 Transaction Management

- **Add Transactions**: Record Income, Expenses, and Transfers with ease.
- **Edit & Delete**: Modify or remove inaccurate entries.
- **Filtering**: Filter transactions by type (Income/Expense/Transfer) and date range.
- **Categorization**: Organize finances with custom icons and colors.
- **Recurring Transactions**: Automate tracking for subscriptions and regular bills.

### 💸 Loan Management

- **Track Loans**: Manage both **Taken Loans** (Borrowings) and **Given Loans** (Lendings).
- **EMI Tracking**: Record EMI payments or receipts directly linked to loans.
- **Loan History**: View a detailed history of all transactions linked to a specific loan.
- **Progress Tracking**: Visual progress bars showing amount paid vs. remaining.

### 💳 Account & Transfer

- **Multiple Accounts**: Manage various accounts (Bank, Cash, Credit Card, etc.).
- **Transfers**: Seamlessly transfer funds between accounts (e.g., paying Credit Card bill from Bank Account).
- **Balance Updates**: Automatic balance adjustments for source and destination accounts.

### 🛠️ Utilities

- **Backup & Restore**: Securely backup your financial data to a local file and restore it when needed.
- **Currency Support**: Global currency support with symbol display.

## 🚀 Technical Stack

- **Framework**: [Flutter](https://flutter.dev/) (Material 3)
- **Language**: Dart
- **State Management**: [Provider](https://pub.dev/packages/provider)
- **Database**: [sqflite](https://pub.dev/packages/sqflite) (SQLite)
- **Preferences**: [shared_preferences](https://pub.dev/packages/shared_preferences)
- **Icons**: [flutter_launcher_icons](https://pub.dev/packages/flutter_launcher_icons)
- **File Handling**: [file_picker](https://pub.dev/packages/file_picker), [permission_handler](https://pub.dev/packages/permission_handler)

## 🗺️ Upcoming Roadmap (Optional Cloud Sync + MCP)

This project is evolving from local-first SQLite to an optional cloud-enabled architecture.
The current app will continue to work offline, while cloud and AI integrations are introduced in phases.

### Phase 1: One-Way Sync (Local -> Supabase)

**Goal**: Keep SQLite as the primary data source and push local changes to Supabase.

**Upcoming Features**

- Optional Supabase setup using user-provided `project URL` and `anon key`.
- Manual sync action from the app.
- Background best-effort upload of local changes.
- Local-first behavior retained (no breaking changes for existing users).

**Tasks**

- [ ] Add `supabase_flutter` dependency and bootstrap client.
- [ ] Create app settings screen section for optional cloud setup.
- [ ] Securely store Supabase credentials/tokens on device.
- [ ] Create Supabase schema for accounts, categories, transactions, recurring transactions, and loans.
- [ ] Add `updated_at` and `deleted_at` columns to synced tables.
- [ ] Build one-way sync service to upload inserts/updates/deletes.
- [ ] Add sync logs and user-visible error feedback.
- [ ] Add migration path for existing local users.

### Phase 2: Two-Way Sync (Local <-> Supabase)

**Goal**: Bi-directional sync with robust conflict handling and user-controlled data mode.

**Upcoming Features**

- Three app modes:
  - Local only
  - Cloud only
  - Hybrid sync
- `sync_status` tracking per record.
- Pull + push sync with conflict resolution.
- Periodic background sync and pull-to-refresh sync.

**Tasks**

- [ ] Add `sync_status` field (for example: pending, synced, conflict, failed).
- [ ] Add `last_synced_at` metadata and per-table sync cursors.
- [ ] Implement server-to-local delta pull by timestamp/version.
- [ ] Implement deterministic conflict strategy (last-write-wins or merge rules).
- [ ] Build conflict UI for manual review when needed.
- [ ] Add settings UI for mode switching and sync controls.
- [ ] Add retry queue with exponential backoff.
- [ ] Add tests for mode switching and sync edge cases.

### Phase 3: Business-Safe FastAPI MCP Server

**Goal**: Provide a secure MCP interface for AI agents without exposing raw database access.

**Upcoming Features**

- Dockerized FastAPI-based MCP server.
- Tool-based business operations (no raw SQL tools).
- Supabase-backed operations with user-controlled deployment.
- Authenticated agent access with audit logs.

**Tasks**

- [ ] Initialize FastAPI project for MCP server.
- [ ] Define MCP tools for safe operations:
  - `get_accounts`
  - `get_transactions`
  - `create_transaction`
  - `update_transaction`
  - `get_monthly_summary`
- [ ] Enforce request validation and domain rules in service layer.
- [ ] Add API authentication and rate limiting.
- [ ] Add structured logging and operation audit trails.
- [ ] Add Dockerfile + docker-compose setup.
- [ ] Publish setup guide for self-hosted user deployment.
- [ ] Add integration tests for all exposed MCP tools.

## ✅ Guiding Principles For The Roadmap

- Offline-first remains the default experience.
- Cloud sync is optional and user-controlled.
- Security before convenience (no service-role keys in mobile app).
- Business-safe AI integration only (no unrestricted data operations).
- Backward compatibility for existing local users.

## 🏁 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
- An IDE (VS Code, Android Studio, etc.).
- Android/iOS Emulator or Physical Device.

### Installation

1.  **Clone the repository**:

    ```bash
    git clone https://github.com/sagaryadav17/hacksilver_ledger.git
    cd hacksilver_ledger
    ```

2.  **Install dependencies**:

    ```bash
    flutter pub get
    ```

3.  **Run the app**:
    ```bash
    flutter run
    ```
