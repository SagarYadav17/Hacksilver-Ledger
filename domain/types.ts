export type TransactionType = 'income' | 'expense' | 'transfer' | 'adjustment';
export type AccountType = 'cash' | 'bank' | 'credit_card' | 'other';
export type LoanType = 'given' | 'taken';
export type Frequency = 'daily' | 'monthly' | 'quarterly' | 'yearly';
export type SyncState = 'idle' | 'syncing' | 'synced' | 'error' | 'conflict';

export interface Category {
  id: string;
  name: string;
  icon: string;
  color: string;
  type: Exclude<TransactionType, 'adjustment'>;
  isCustom: boolean;
  isArchived: boolean;
  sortOrder: number;
  updatedAt: string;
  deletedAt?: string | null;
}

export interface Account {
  id: string;
  name: string;
  type: AccountType;
  balance: number;
  updatedAt: string;
  deletedAt?: string | null;
}

export interface Transaction {
  id: string;
  title: string;
  amount: number;
  date: string;
  type: TransactionType;
  categoryId: string;
  accountId?: string | null;
  transferAccountId?: string | null;
  notes?: string | null;
  originalAmount?: number | null;
  originalCurrency?: string | null;
  loanId?: string | null;
  recurringId?: string | null;
  updatedAt: string;
  deletedAt?: string | null;
}

export interface Loan {
  id: string;
  title: string;
  amount: number;
  interestRate: number;
  tenureMonths: number;
  type: LoanType;
  startDate: string;
  emiAmount: number;
  amountPaid: number;
  isClosed: boolean;
  notes?: string | null;
  updatedAt: string;
  deletedAt?: string | null;
}

export interface RecurringTransaction {
  id: string;
  title: string;
  amount: number;
  type: Exclude<TransactionType, 'adjustment'>;
  categoryId: string;
  accountId?: string | null;
  frequency: Frequency;
  startDate: string;
  nextDueDate: string;
  isActive: boolean;
  notes?: string | null;
  updatedAt: string;
  deletedAt?: string | null;
}

export interface TransactionInput {
  title: string;
  amount: number;
  date: string;
  type: TransactionType;
  categoryId: string;
  accountId?: string | null;
  transferAccountId?: string | null;
  notes?: string | null;
  originalAmount?: number | null;
  originalCurrency?: string | null;
  loanId?: string | null;
  recurringId?: string | null;
}

export interface TransactionFilters {
  search?: string;
  type?: TransactionType | 'all';
  from?: string;
  to?: string;
  sort?: 'date_desc' | 'date_asc' | 'amount_desc' | 'amount_asc';
}

export interface DashboardSummary {
  balance: number;
  income: number;
  expenses: number;
  savingsRate: number;
  monthLabel: string;
}

export interface SyncResult {
  success: boolean;
  pushed: number;
  pulled: number;
  conflicts: number;
  error?: string;
}

export interface BackupRecord {
  id: string;
  uri: string;
  sizeBytes: number;
  checksum: string;
  createdAt: string;
  kind: 'export' | 'pre_restore';
}

export const TRANSACTION_TYPES: Array<{ key: TransactionType; label: string }> = [
  { key: 'expense', label: 'Expense' },
  { key: 'income', label: 'Income' },
  { key: 'transfer', label: 'Transfer' },
  { key: 'adjustment', label: 'Adjustment' },
];

export function newId(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (character) => {
    const random = Math.floor(Math.random() * 16);
    const value = character === 'x' ? random : (random & 0x3) | 0x8;
    return value.toString(16);
  });
}

export function nowIso(): string {
  return new Date().toISOString();
}
