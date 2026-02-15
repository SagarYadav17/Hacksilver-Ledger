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
