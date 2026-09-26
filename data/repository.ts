import type { SQLiteDatabase } from 'expo-sqlite';
import Decimal from 'decimal.js-light';
import {
  type Account,
  type AccountType,
  type Category,
  type DashboardSummary,
  type Loan,
  type RecurringTransaction,
  type Transaction,
  type TransactionFilters,
  type TransactionInput,
  nowIso,
  newId,
} from '@/domain/types';

type DbCategory = Record<string, unknown>;
type DbAccount = Record<string, unknown>;
type DbTransaction = Record<string, unknown>;

function bool(value: unknown): boolean {
  return Number(value) === 1;
}

function asNumber(value: unknown): number {
  return Number(value ?? 0);
}

function mapCategory(row: DbCategory): Category {
  return {
    id: String(row.id),
    name: String(row.name),
    icon: String(row.icon),
    color: String(row.color),
    type: row.type as Category['type'],
    isCustom: bool(row.is_custom),
    isArchived: bool(row.is_archived),
    sortOrder: asNumber(row.sort_order),
    updatedAt: String(row.updated_at),
    deletedAt: row.deleted_at as string | null,
  };
}

function mapAccount(row: DbAccount): Account {
  return {
    id: String(row.id),
    name: String(row.name),
    type: row.type as AccountType,
    balance: asNumber(row.balance),
    updatedAt: String(row.updated_at),
    deletedAt: row.deleted_at as string | null,
  };
}

function mapTransaction(row: DbTransaction): Transaction {
  return {
    id: String(row.id),
    title: String(row.title),
    amount: asNumber(row.amount),
    date: String(row.date),
    type: row.type as Transaction['type'],
    categoryId: String(row.category_id),
    accountId: row.account_id as string | null,
    transferAccountId: row.transfer_account_id as string | null,
    notes: row.notes as string | null,
    originalAmount: row.original_amount as number | null,
    originalCurrency: row.original_currency as string | null,
    loanId: row.loan_id as string | null,
    recurringId: row.recurring_id as string | null,
    updatedAt: String(row.updated_at),
    deletedAt: row.deleted_at as string | null,
  };
}

function mapLoan(row: Record<string, unknown>): Loan {
  return {
    id: String(row.id),
    title: String(row.title),
    amount: asNumber(row.amount),
    interestRate: asNumber(row.interest_rate),
    tenureMonths: asNumber(row.tenure_months),
    type: row.type as Loan['type'],
    startDate: String(row.start_date),
    emiAmount: asNumber(row.emi_amount),
    amountPaid: asNumber(row.amount_paid),
    isClosed: bool(row.is_closed),
    notes: row.notes as string | null,
    updatedAt: String(row.updated_at),
    deletedAt: row.deleted_at as string | null,
  };
}

function mapRecurring(row: Record<string, unknown>): RecurringTransaction {
  return {
    id: String(row.id),
    title: String(row.title),
    amount: asNumber(row.amount),
    type: row.type as RecurringTransaction['type'],
    categoryId: String(row.category_id),
    accountId: row.account_id as string | null,
    frequency: row.frequency as RecurringTransaction['frequency'],
    startDate: String(row.start_date),
    nextDueDate: String(row.next_due_date),
    isActive: bool(row.is_active),
    notes: row.notes as string | null,
    updatedAt: String(row.updated_at),
    deletedAt: row.deleted_at as string | null,
  };
}

function signedAccountDelta(type: Transaction['type'], amount: number): Decimal {
  if (type === 'income') return new Decimal(amount);
  if (type === 'expense') return new Decimal(amount).negated();
  return new Decimal(0);
}

export class LedgerRepository {
  constructor(private readonly db: SQLiteDatabase) {}

  async getCategories(includeArchived = false): Promise<Category[]> {
    const rows = await this.db.getAllAsync<DbCategory>(
      `SELECT * FROM categories WHERE deleted_at IS NULL ${includeArchived ? '' : 'AND is_archived = 0'} ORDER BY sort_order, name`,
    );
    return rows.map(mapCategory);
  }

  async getAccounts(): Promise<Account[]> {
    const rows = await this.db.getAllAsync<DbAccount>('SELECT * FROM accounts WHERE deleted_at IS NULL ORDER BY name');
    return rows.map(mapAccount);
  }

  async getTransactions(filters: TransactionFilters = {}): Promise<Transaction[]> {
    const where = ['t.deleted_at IS NULL'];
    const params: Array<string | number> = [];
    if (filters.search?.trim()) {
      where.push("(LOWER(t.title) LIKE ? OR LOWER(COALESCE(t.notes, '')) LIKE ?)");
      const term = `%${filters.search.trim().toLowerCase()}%`;
      params.push(term, term);
    }
    if (filters.type && filters.type !== 'all') {
      where.push('t.type = ?');
      params.push(filters.type);
    }
    if (filters.from) {
      where.push('t.date >= ?');
      params.push(filters.from);
    }
    if (filters.to) {
      where.push('t.date <= ?');
      params.push(filters.to);
    }
    const order =
      filters.sort === 'date_asc'
        ? 't.date ASC'
        : filters.sort === 'amount_desc'
          ? 't.amount DESC'
          : filters.sort === 'amount_asc'
            ? 't.amount ASC'
            : 't.date DESC';
    const rows = await this.db.getAllAsync<DbTransaction>(
      `SELECT t.* FROM transactions t WHERE ${where.join(' AND ')} ORDER BY ${order}, t.updated_at DESC`,
      params,
    );
    return rows.map(mapTransaction);
  }

  async getLoans(): Promise<Loan[]> {
    const rows = await this.db.getAllAsync<Record<string, unknown>>(
      'SELECT * FROM loans WHERE deleted_at IS NULL ORDER BY is_closed, start_date DESC',
    );
    return rows.map(mapLoan);
  }

  async getRecurringTransactions(): Promise<RecurringTransaction[]> {
    const rows = await this.db.getAllAsync<Record<string, unknown>>(
      'SELECT * FROM recurring_transactions WHERE deleted_at IS NULL ORDER BY next_due_date',
    );
    return rows.map(mapRecurring);
  }

  async getDashboardSummary(date = new Date()): Promise<DashboardSummary> {
    const monthStart = new Date(date.getFullYear(), date.getMonth(), 1).toISOString();
    const monthEnd = new Date(date.getFullYear(), date.getMonth() + 1, 1).toISOString();
    const rows = await this.db.getAllAsync<{ type: string; total: number }>(
      `SELECT type, COALESCE(SUM(amount), 0) as total FROM transactions WHERE deleted_at IS NULL AND date >= ? AND date < ? GROUP BY type`,
      monthStart,
      monthEnd,
    );
    const all = await this.db.getFirstAsync<{ balance: number }>(
      'SELECT COALESCE(SUM(balance), 0) as balance FROM accounts WHERE deleted_at IS NULL',
    );
    const income = rows.find((row) => row.type === 'income')?.total ?? 0;
    const expenses = rows.find((row) => row.type === 'expense')?.total ?? 0;
    const savingsRate = income > 0 ? Math.round(((income - expenses) / income) * 100) : 0;
    return {
      balance: all?.balance ?? 0,
      income,
      expenses,
      savingsRate,
      monthLabel: date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' }),
    };
  }

  private async applyAccountDelta(accountId: string | null | undefined, delta: Decimal): Promise<void> {
    if (!accountId || delta.isZero()) return;
    await this.db.runAsync(
      'UPDATE accounts SET balance = balance + ?, updated_at = ? WHERE id = ?',
      Number(delta.toFixed(2)),
      nowIso(),
      accountId,
    );
  }

  private async applyTransactionEffects(input: TransactionInput, direction: 1 | -1): Promise<void> {
    const multiplier = new Decimal(direction);
    await this.applyAccountDelta(input.accountId, signedAccountDelta(input.type, input.amount).mul(multiplier));
    if (input.type === 'transfer') {
      await this.applyAccountDelta(input.accountId, new Decimal(input.amount).negated().mul(multiplier));
      await this.applyAccountDelta(input.transferAccountId, new Decimal(input.amount).mul(multiplier));
    }
  }

  async createTransaction(input: TransactionInput): Promise<Transaction> {
    const transaction: Transaction = { ...input, id: newId(), updatedAt: nowIso(), deletedAt: null };
    await this.db.withTransactionAsync(async () => {
      await this.db.runAsync(
        `INSERT INTO transactions (id, title, amount, date, type, category_id, account_id, transfer_account_id, notes, original_amount, original_currency, loan_id, recurring_id, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        transaction.id,
        transaction.title,
        transaction.amount,
        transaction.date,
        transaction.type,
        transaction.categoryId,
        transaction.accountId ?? null,
        transaction.transferAccountId ?? null,
        transaction.notes ?? null,
        transaction.originalAmount ?? null,
        transaction.originalCurrency ?? null,
        transaction.loanId ?? null,
        transaction.recurringId ?? null,
        transaction.updatedAt,
      );
      await this.applyTransactionEffects(input, 1);
    });
    return transaction;
  }

  async deleteTransaction(id: string): Promise<void> {
    const existing = await this.db.getFirstAsync<DbTransaction>(
      'SELECT * FROM transactions WHERE id = ? AND deleted_at IS NULL',
      id,
    );
    if (!existing) return;
    const transaction = mapTransaction(existing);
    await this.db.withTransactionAsync(async () => {
      await this.applyTransactionEffects(transaction, -1);
      await this.db.runAsync(
        'UPDATE transactions SET deleted_at = ?, updated_at = ? WHERE id = ?',
        nowIso(),
        nowIso(),
        id,
      );
    });
  }

  async updateTransaction(id: string, input: TransactionInput): Promise<Transaction> {
    const existingRow = await this.db.getFirstAsync<DbTransaction>(
      'SELECT * FROM transactions WHERE id = ? AND deleted_at IS NULL',
      id,
    );
    if (!existingRow) throw new Error('Transaction not found');
    const existing = mapTransaction(existingRow);
    const transaction: Transaction = { ...input, id, updatedAt: nowIso(), deletedAt: null };
    await this.db.withTransactionAsync(async () => {
      await this.applyTransactionEffects(existing, -1);
      await this.db.runAsync(
        `UPDATE transactions SET title = ?, amount = ?, date = ?, type = ?, category_id = ?, account_id = ?, transfer_account_id = ?, notes = ?, original_amount = ?, original_currency = ?, loan_id = ?, recurring_id = ?, updated_at = ? WHERE id = ?`,
        transaction.title,
        transaction.amount,
        transaction.date,
        transaction.type,
        transaction.categoryId,
        transaction.accountId ?? null,
        transaction.transferAccountId ?? null,
        transaction.notes ?? null,
        transaction.originalAmount ?? null,
        transaction.originalCurrency ?? null,
        transaction.loanId ?? null,
        transaction.recurringId ?? null,
        transaction.updatedAt,
        id,
      );
      await this.applyTransactionEffects(input, 1);
    });
    return transaction;
  }

  async createAccount(name: string, type: AccountType): Promise<Account> {
    const account: Account = { id: newId(), name, type, balance: 0, updatedAt: nowIso(), deletedAt: null };
    await this.db.runAsync(
      'INSERT INTO accounts (id, name, type, balance, updated_at) VALUES (?, ?, ?, 0, ?)',
      account.id,
      name,
      type,
      account.updatedAt,
    );
    return account;
  }

  async reconcileAccount(id: string, balance: number): Promise<void> {
    if (!Number.isFinite(balance)) throw new Error('Enter a valid balance');
    const account = await this.db.getFirstAsync<{ id: string }>(
      'SELECT id FROM accounts WHERE id = ? AND deleted_at IS NULL',
      id,
    );
    if (!account) throw new Error('Account not found');
    await this.db.runAsync(
      'UPDATE accounts SET balance = ?, updated_at = ? WHERE id = ?',
      Number(new Decimal(balance).toFixed(2)),
      nowIso(),
      id,
    );
  }

  async createCategory(name: string, type: Category['type'], color: string, icon = 'category'): Promise<Category> {
    const sort = await this.db.getFirstAsync<{ max: number }>(
      'SELECT COALESCE(MAX(sort_order), 0) as max FROM categories',
    );
    const category: Category = {
      id: newId(),
      name,
      type,
      color,
      icon,
      isCustom: true,
      isArchived: false,
      sortOrder: (sort?.max ?? 0) + 1,
      updatedAt: nowIso(),
      deletedAt: null,
    };
    await this.db.runAsync(
      'INSERT INTO categories (id, name, icon, color, type, is_custom, sort_order, updated_at) VALUES (?, ?, ?, ?, ?, 1, ?, ?)',
      category.id,
      name,
      icon,
      color,
      type,
      category.sortOrder,
      category.updatedAt,
    );
    return category;
  }

  async setCategoryArchived(id: string, archived: boolean): Promise<void> {
    await this.db.runAsync(
      'UPDATE categories SET is_archived = ?, updated_at = ? WHERE id = ?',
      archived ? 1 : 0,
      nowIso(),
      id,
    );
  }

  async mergeCategories(sourceId: string, targetId: string): Promise<void> {
    await this.db.withTransactionAsync(async () => {
      await this.db.runAsync(
        'UPDATE transactions SET category_id = ?, updated_at = ? WHERE category_id = ? AND deleted_at IS NULL',
        targetId,
        nowIso(),
        sourceId,
      );
      await this.db.runAsync(
        'UPDATE recurring_transactions SET category_id = ?, updated_at = ? WHERE category_id = ? AND deleted_at IS NULL',
        targetId,
        nowIso(),
        sourceId,
      );
      await this.setCategoryArchived(sourceId, true);
    });
  }

  async createLoan(input: Omit<Loan, 'id' | 'updatedAt' | 'deletedAt' | 'amountPaid' | 'isClosed'>): Promise<Loan> {
    const loan: Loan = { ...input, id: newId(), amountPaid: 0, isClosed: false, updatedAt: nowIso(), deletedAt: null };
    await this.db.runAsync(
      `INSERT INTO loans (id, title, amount, interest_rate, tenure_months, type, start_date, emi_amount, amount_paid, is_closed, notes, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, 0, ?, ?)`,
      loan.id,
      loan.title,
      loan.amount,
      loan.interestRate,
      loan.tenureMonths,
      loan.type,
      loan.startDate,
      loan.emiAmount,
      loan.notes ?? null,
      loan.updatedAt,
    );
    return loan;
  }

  async createRecurring(
    input: Omit<RecurringTransaction, 'id' | 'updatedAt' | 'deletedAt'>,
  ): Promise<RecurringTransaction> {
    const recurring: RecurringTransaction = { ...input, id: newId(), updatedAt: nowIso(), deletedAt: null };
    await this.db.runAsync(
      `INSERT INTO recurring_transactions (id, title, amount, type, category_id, account_id, frequency, start_date, next_due_date, is_active, notes, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      recurring.id,
      recurring.title,
      recurring.amount,
      recurring.type,
      recurring.categoryId,
      recurring.accountId ?? null,
      recurring.frequency,
      recurring.startDate,
      recurring.nextDueDate,
      recurring.isActive ? 1 : 0,
      recurring.notes ?? null,
      recurring.updatedAt,
    );
    return recurring;
  }

  async setRecurringActive(id: string, active: boolean): Promise<void> {
    await this.db.runAsync(
      'UPDATE recurring_transactions SET is_active = ?, updated_at = ? WHERE id = ?',
      active ? 1 : 0,
      nowIso(),
      id,
    );
  }

  async recordLoanPayment(loanId: string, amount: number, accountId?: string | null): Promise<void> {
    const loan = await this.db.getFirstAsync<Record<string, unknown>>(
      'SELECT * FROM loans WHERE id = ? AND deleted_at IS NULL',
      loanId,
    );
    if (!loan) throw new Error('Loan not found');
    const type = loan.type === 'given' ? 'income' : 'expense';
    const category = await this.db.getFirstAsync<{ id: string }>(
      'SELECT id FROM categories WHERE type = ? AND is_archived = 0 ORDER BY sort_order LIMIT 1',
      type,
    );
    if (!category) throw new Error('No category available for this payment');
    await this.db.withTransactionAsync(async () => {
      const currentPaid = asNumber(loan.amount_paid);
      const nextPaid = Math.min(asNumber(loan.amount), currentPaid + amount);
      await this.db.runAsync(
        'UPDATE loans SET amount_paid = ?, is_closed = ?, updated_at = ? WHERE id = ?',
        nextPaid,
        nextPaid >= asNumber(loan.amount) ? 1 : 0,
        nowIso(),
        loanId,
      );
      const input: TransactionInput = {
        title: `${String(loan.title)} payment`,
        amount,
        date: nowIso(),
        type,
        categoryId: category.id,
        accountId: accountId ?? null,
        loanId,
      };
      await this.db.runAsync(
        'INSERT INTO transactions (id, title, amount, date, type, category_id, account_id, loan_id, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        newId(),
        input.title,
        input.amount,
        input.date,
        input.type,
        input.categoryId,
        input.accountId ?? null,
        loanId,
        nowIso(),
      );
      await this.applyTransactionEffects(input, 1);
    });
  }

  async updateRecurring(id: string, patch: Partial<RecurringTransaction>): Promise<void> {
    const keyMap: Record<string, string> = {
      title: 'title',
      amount: 'amount',
      type: 'type',
      categoryId: 'category_id',
      accountId: 'account_id',
      frequency: 'frequency',
      startDate: 'start_date',
      nextDueDate: 'next_due_date',
      isActive: 'is_active',
      notes: 'notes',
    };
    const entries = Object.entries(patch)
      .filter(([key]) => keyMap[key])
      .map(([key, value]) => [keyMap[key], typeof value === 'boolean' ? (value ? 1 : 0) : value] as const);
    if (!entries.length) return;
    const fields = entries.map(([key]) => `${key} = ?`).join(', ');
    await this.db.runAsync(
      `UPDATE recurring_transactions SET ${fields}, updated_at = ? WHERE id = ?`,
      ...entries.map(([, value]) => value as string | number),
      nowIso(),
      id,
    );
  }

  async getSyncMetadata(): Promise<{ lastSyncAt: string | null; lastError: string | null; pendingCount: number }> {
    const row = await this.db.getFirstAsync<{
      last_sync_at: string | null;
      last_error: string | null;
      pending_count: number;
    }>('SELECT last_sync_at, last_error, pending_count FROM sync_metadata WHERE id = 1');
    const since = row?.last_sync_at ?? '1970-01-01T00:00:00.000Z';
    const pending = await this.db.getFirstAsync<{ count: number }>(
      `SELECT (SELECT COUNT(*) FROM transactions WHERE updated_at > ?) + (SELECT COUNT(*) FROM accounts WHERE updated_at > ?) + (SELECT COUNT(*) FROM categories WHERE updated_at > ?) + (SELECT COUNT(*) FROM loans WHERE updated_at > ?) + (SELECT COUNT(*) FROM recurring_transactions WHERE updated_at > ?) AS count`,
      since,
      since,
      since,
      since,
      since,
    );
    return {
      lastSyncAt: row?.last_sync_at ?? null,
      lastError: row?.last_error ?? null,
      pendingCount: pending?.count ?? 0,
    };
  }

  async recordSync(result: {
    status: string;
    pushed: number;
    pulled: number;
    conflicts: number;
    message?: string;
  }): Promise<void> {
    const timestamp = nowIso();
    await this.db.runAsync(
      'INSERT INTO sync_history (id, status, pushed, pulled, conflicts, message, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      newId(),
      result.status,
      result.pushed,
      result.pulled,
      result.conflicts,
      result.message ?? null,
      timestamp,
    );
    await this.db.runAsync(
      'UPDATE sync_metadata SET last_sync_at = ?, last_error = ? WHERE id = 1',
      result.status === 'success' ? timestamp : null,
      result.message ?? null,
    );
  }
}
