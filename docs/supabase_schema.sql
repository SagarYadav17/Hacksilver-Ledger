-- Supabase Schema for Hacksilver-Ledger Phase 1 Sync
-- Run this SQL in your Supabase SQL Editor

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- CATEGORIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    local_id INTEGER,
    name TEXT NOT NULL,
    icon_code INTEGER NOT NULL,
    font_family TEXT,
    font_package TEXT,
    color_value INTEGER NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    is_custom BOOLEAN DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

-- Index for soft delete filtering
CREATE INDEX idx_categories_deleted_at ON categories(deleted_at);
CREATE INDEX idx_categories_updated_at ON categories(updated_at);

-- Enable RLS
ALTER TABLE categories ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Allow all operations for authenticated users
CREATE POLICY "Allow all operations for authenticated users" ON categories
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- ACCOUNTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    local_id INTEGER,
    name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('cash', 'bank', 'creditCard', 'other')),
    balance REAL NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_accounts_deleted_at ON accounts(deleted_at);
CREATE INDEX idx_accounts_updated_at ON accounts(updated_at);

ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations for authenticated users" ON accounts
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- TRANSACTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    local_id INTEGER,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    date TIMESTAMPTZ NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    category_id INTEGER,
    account_id INTEGER,
    transfer_account_id INTEGER,
    notes TEXT,
    original_amount REAL,
    original_currency TEXT,
    loan_id INTEGER,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_transactions_deleted_at ON transactions(deleted_at);
CREATE INDEX idx_transactions_updated_at ON transactions(updated_at);
CREATE INDEX idx_transactions_date ON transactions(date);

ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations for authenticated users" ON transactions
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- LOANS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS loans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    local_id INTEGER,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    interest_rate REAL NOT NULL DEFAULT 0,
    tenure_months INTEGER NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('given', 'taken')),
    start_date TIMESTAMPTZ NOT NULL,
    emi_amount REAL NOT NULL DEFAULT 0,
    amount_paid REAL NOT NULL DEFAULT 0,
    is_closed BOOLEAN DEFAULT false,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_loans_deleted_at ON loans(deleted_at);
CREATE INDEX idx_loans_updated_at ON loans(updated_at);

ALTER TABLE loans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations for authenticated users" ON loans
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- RECURRING TRANSACTIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS recurring_transactions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    local_id INTEGER,
    title TEXT NOT NULL,
    amount REAL NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('income', 'expense', 'transfer')),
    category_id INTEGER,
    account_id INTEGER,
    frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'monthly', 'quarterly', 'yearly')),
    start_date TIMESTAMPTZ NOT NULL,
    next_due_date TIMESTAMPTZ NOT NULL,
    is_active BOOLEAN DEFAULT true,
    notes TEXT,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE INDEX idx_recurring_transactions_deleted_at ON recurring_transactions(deleted_at);
CREATE INDEX idx_recurring_transactions_updated_at ON recurring_transactions(updated_at);

ALTER TABLE recurring_transactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations for authenticated users" ON recurring_transactions
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- SYNC METADATA TABLE (Optional, for future use)
-- ============================================
CREATE TABLE IF NOT EXISTS sync_metadata (
    id INTEGER PRIMARY KEY DEFAULT 1,
    device_id TEXT,
    last_sync_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE sync_metadata ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow all operations for authenticated users" ON sync_metadata
    FOR ALL
    TO authenticated
    USING (true)
    WITH CHECK (true);

-- ============================================
-- FUNCTIONS
-- ============================================

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply trigger to all tables
CREATE TRIGGER update_categories_updated_at BEFORE UPDATE ON categories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_accounts_updated_at BEFORE UPDATE ON accounts
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_transactions_updated_at BEFORE UPDATE ON transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loans_updated_at BEFORE UPDATE ON loans
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_recurring_transactions_updated_at BEFORE UPDATE ON recurring_transactions
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ============================================
-- SAMPLE QUERIES FOR TESTING
-- ============================================

-- View all active (not soft-deleted) categories
-- SELECT * FROM categories WHERE deleted_at IS NULL;

-- View all records pending sync since a specific time
-- SELECT * FROM transactions WHERE updated_at > '2025-01-01' AND deleted_at IS NULL;

-- Count of records by table
-- SELECT 'categories' as table_name, COUNT(*) FROM categories WHERE deleted_at IS NULL
-- UNION ALL
-- SELECT 'accounts', COUNT(*) FROM accounts WHERE deleted_at IS NULL
-- UNION ALL
-- SELECT 'transactions', COUNT(*) FROM transactions WHERE deleted_at IS NULL
-- UNION ALL
-- SELECT 'loans', COUNT(*) FROM loans WHERE deleted_at IS NULL
-- UNION ALL
-- SELECT 'recurring_transactions', COUNT(*) FROM recurring_transactions WHERE deleted_at IS NULL;
