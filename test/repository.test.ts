import { describe, expect, test } from 'bun:test';
import type { SQLiteDatabase } from 'expo-sqlite';
import { initializeDatabase } from '../data/schema';
import { LedgerRepository } from '../data/repository';
import { MemoryDatabase } from './memory-db';

async function createFixture() {
  const database = new MemoryDatabase();
  await initializeDatabase(database as unknown as SQLiteDatabase);
  const repository = new LedgerRepository(database as unknown as SQLiteDatabase);
  const categories = await repository.getCategories();
  const account = await repository.createAccount('Main account', 'bank');
  return {
    database,
    repository,
    account,
    expense: categories.find((item) => item.type === 'expense')!,
    income: categories.find((item) => item.type === 'income')!,
    transfer: categories.find((item) => item.type === 'transfer')!,
  };
}

describe('LedgerRepository', () => {
  test('applies income, expense, and transfer effects to accounts', async () => {
    const fixture = await createFixture();
    const cash = await fixture.repository.createAccount('Cash', 'cash');

    await fixture.repository.createTransaction({
      title: 'Salary',
      amount: 1000,
      date: new Date().toISOString(),
      type: 'income',
      categoryId: fixture.income.id,
      accountId: fixture.account.id,
    });
    const expense = await fixture.repository.createTransaction({
      title: 'Groceries',
      amount: 250,
      date: new Date().toISOString(),
      type: 'expense',
      categoryId: fixture.expense.id,
      accountId: fixture.account.id,
    });
    await fixture.repository.createTransaction({
      title: 'Move to cash',
      amount: 200,
      date: new Date().toISOString(),
      type: 'transfer',
      categoryId: fixture.transfer.id,
      accountId: fixture.account.id,
      transferAccountId: cash.id,
    });

    expect((await fixture.repository.getAccounts()).find((item) => item.id === fixture.account.id)?.balance).toBe(550);
    expect((await fixture.repository.getAccounts()).find((item) => item.id === cash.id)?.balance).toBe(200);

    await fixture.repository.deleteTransaction(expense.id);
    expect((await fixture.repository.getAccounts()).find((item) => item.id === fixture.account.id)?.balance).toBe(800);
  });

  test('reverses old effects when a transaction is edited', async () => {
    const fixture = await createFixture();
    const transaction = await fixture.repository.createTransaction({
      title: 'Coffee',
      amount: 100,
      date: new Date().toISOString(),
      type: 'expense',
      categoryId: fixture.expense.id,
      accountId: fixture.account.id,
    });

    await fixture.repository.updateTransaction(transaction.id, { ...transaction, amount: 40 });

    expect((await fixture.repository.getAccounts()).find((item) => item.id === fixture.account.id)?.balance).toBe(-40);
    expect((await fixture.repository.getTransactions()).find((item) => item.id === transaction.id)?.amount).toBe(40);
  });

  test('records loan payments as linked transactions and updates progress', async () => {
    const fixture = await createFixture();
    const loan = await fixture.repository.createLoan({
      title: 'Family loan',
      amount: 600,
      interestRate: 0,
      tenureMonths: 6,
      type: 'taken',
      startDate: new Date().toISOString(),
      emiAmount: 100,
      notes: null,
    });

    await fixture.repository.recordLoanPayment(loan.id, 100, fixture.account.id);

    expect((await fixture.repository.getLoans()).find((item) => item.id === loan.id)?.amountPaid).toBe(100);
    expect((await fixture.repository.getAccounts()).find((item) => item.id === fixture.account.id)?.balance).toBe(-100);
    expect((await fixture.repository.getTransactions()).find((item) => item.loanId === loan.id)?.title).toBe(
      'Family loan payment',
    );
  });

  test('reconciles an account to a verified external balance', async () => {
    const fixture = await createFixture();

    await fixture.repository.reconcileAccount(fixture.account.id, 1234.567);

    expect((await fixture.repository.getAccounts()).find((item) => item.id === fixture.account.id)?.balance).toBe(
      1234.57,
    );
  });
});

const balanceOf = async (repository: LedgerRepository, id: string) =>
  (await repository.getAccounts()).find((item) => item.id === id)?.balance;

describe('transaction validation and adjustments', () => {
  test('adjustments apply signed deltas using an on-demand system category', async () => {
    const fixture = await createFixture();
    const base = { title: 'Fix', date: new Date().toISOString(), type: 'adjustment' as const, categoryId: '' };
    const up = await fixture.repository.createTransaction({ ...base, amount: 150.456, accountId: fixture.account.id });
    const down = await fixture.repository.createTransaction({ ...base, amount: -50, accountId: fixture.account.id });
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(100.46);
    expect(up.amount).toBe(150.46);
    expect(up.categoryId).toBe(down.categoryId);
    const category = (await fixture.repository.getCategories()).find((item) => item.id === up.categoryId);
    expect(category).toMatchObject({ name: 'Adjustment', isCustom: false });
    await fixture.repository.deleteTransaction(down.id);
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(150.46);
    const summary = await fixture.repository.getDashboardSummary();
    expect(summary.income).toBe(0);
    expect(summary.expenses).toBe(0);
  });

  test('rejects invalid amounts, zero adjustments, and bad transfers', async () => {
    const fixture = await createFixture();
    const base = {
      title: 'Bad',
      date: new Date().toISOString(),
      categoryId: fixture.expense.id,
      accountId: fixture.account.id,
    };
    const create = fixture.repository.createTransaction.bind(fixture.repository);
    await expect(create({ ...base, type: 'expense', amount: Number.NaN })).rejects.toThrow();
    await expect(create({ ...base, type: 'expense', amount: Number.POSITIVE_INFINITY })).rejects.toThrow();
    await expect(create({ ...base, type: 'expense', amount: -5 })).rejects.toThrow();
    await expect(create({ ...base, type: 'income', amount: 0 })).rejects.toThrow();
    await expect(create({ ...base, type: 'adjustment', amount: 0 })).rejects.toThrow();
    await expect(create({ ...base, type: 'adjustment', amount: 5, accountId: null })).rejects.toThrow();
    await expect(
      create({
        ...base,
        type: 'transfer',
        amount: 5,
        categoryId: fixture.transfer.id,
        transferAccountId: fixture.account.id,
      }),
    ).rejects.toThrow('different');
    await expect(create({ ...base, type: 'transfer', amount: 5, categoryId: fixture.transfer.id })).rejects.toThrow();
    const ok = await create({ ...base, type: 'expense', amount: 10 });
    await expect(fixture.repository.updateTransaction(ok.id, { ...ok, amount: Number.NaN })).rejects.toThrow();
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(-10);
    expect(await fixture.repository.getTransactions()).toHaveLength(1);
  });

  test('rounds amounts and balances to 2dp', async () => {
    const fixture = await createFixture();
    const base = { date: new Date().toISOString(), type: 'income' as const, categoryId: fixture.income.id };
    await fixture.repository.createTransaction({ ...base, title: 'a', amount: 0.1, accountId: fixture.account.id });
    await fixture.repository.createTransaction({ ...base, title: 'b', amount: 0.2, accountId: fixture.account.id });
    await fixture.repository.createTransaction({ ...base, title: 'c', amount: 1.005, accountId: fixture.account.id });
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(1.31);
  });
});

const createLoan = (repository: LedgerRepository, type: 'given' | 'taken') =>
  repository.createLoan({
    title: 'Loan',
    amount: 500,
    interestRate: 0,
    tenureMonths: 5,
    type,
    startDate: new Date().toISOString(),
    emiAmount: 100,
    notes: null,
  });

describe('loan payments', () => {
  test('rejects non-positive and over-payments', async () => {
    const fixture = await createFixture();
    const loan = await createLoan(fixture.repository, 'taken');
    await expect(fixture.repository.recordLoanPayment(loan.id, 0)).rejects.toThrow();
    await expect(fixture.repository.recordLoanPayment(loan.id, -10)).rejects.toThrow();
    await expect(fixture.repository.recordLoanPayment(loan.id, Number.NaN)).rejects.toThrow();
    await fixture.repository.recordLoanPayment(loan.id, 400);
    await expect(fixture.repository.recordLoanPayment(loan.id, 100.01)).rejects.toThrow('remaining');
    await fixture.repository.recordLoanPayment(loan.id, 100);
    const updated = (await fixture.repository.getLoans())[0];
    expect(updated.amountPaid).toBe(500);
    expect(updated.isClosed).toBe(true);
    await expect(fixture.repository.recordLoanPayment('missing', 1)).rejects.toThrow('not found');
  });

  test('uses a dedicated Loans category per direction', async () => {
    const fixture = await createFixture();
    const taken = await createLoan(fixture.repository, 'taken');
    const given = await createLoan(fixture.repository, 'given');
    await fixture.repository.recordLoanPayment(taken.id, 50, fixture.account.id);
    await fixture.repository.recordLoanPayment(taken.id, 50, fixture.account.id);
    await fixture.repository.recordLoanPayment(given.id, 30, fixture.account.id);
    const categories = await fixture.repository.getCategories();
    const loans = categories.filter((item) => item.name === 'Loans');
    expect(loans.map((item) => item.type).toSorted()).toEqual(['expense', 'income']);
    expect(loans.every((item) => !item.isCustom)).toBe(true);
    const transactions = await fixture.repository.getTransactions();
    expect(transactions.find((item) => item.loanId === given.id)?.categoryId).toBe(
      loans.find((item) => item.type === 'income')?.id,
    );
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(-70);
  });

  test('validates loan terms', async () => {
    const fixture = await createFixture();
    const base = {
      title: 'L',
      amount: 100,
      interestRate: 5,
      tenureMonths: 12,
      type: 'taken' as const,
      startDate: new Date().toISOString(),
      emiAmount: 10,
      notes: null,
    };
    await expect(fixture.repository.createLoan({ ...base, amount: Number.NaN })).rejects.toThrow();
    await expect(fixture.repository.createLoan({ ...base, tenureMonths: 1.5 })).rejects.toThrow();
    await expect(fixture.repository.createLoan({ ...base, tenureMonths: 601 })).rejects.toThrow();
    await expect(fixture.repository.createLoan({ ...base, interestRate: 101 })).rejects.toThrow();
  });
});

const local = (year: number, month: number, day: number) => new Date(year, month - 1, day).toISOString();
const createRecurring = (fixture: Awaited<ReturnType<typeof createFixture>>, start: string, frequency = 'monthly') =>
  fixture.repository.createRecurring({
    title: 'Rent',
    amount: 1000,
    type: 'expense',
    categoryId: fixture.expense.id,
    accountId: fixture.account.id,
    frequency: frequency as 'monthly',
    startDate: start,
    nextDueDate: start,
    isActive: true,
    notes: null,
  });

describe('recurring posting', () => {
  test('posts due occurrences, advances month-end safely, and is idempotent', async () => {
    const fixture = await createFixture();
    const recurring = await createRecurring(fixture, local(2024, 1, 31));
    const now = new Date(2024, 3, 15);
    expect(await fixture.repository.postDueRecurring(now)).toBe(3);
    expect(await fixture.repository.postDueRecurring(now)).toBe(0);
    const posted = await fixture.repository.getTransactions({ sort: 'date_asc' });
    expect(posted.map((item) => item.date)).toEqual([local(2024, 1, 31), local(2024, 2, 29), local(2024, 3, 31)]);
    expect(posted.every((item) => item.recurringId === recurring.id)).toBe(true);
    expect((await fixture.repository.getRecurringTransactions())[0].nextDueDate).toBe(local(2024, 4, 30));
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(-3000);
  });

  test('skips paused entries and supports other frequencies', async () => {
    const fixture = await createFixture();
    const paused = await createRecurring(fixture, local(2024, 1, 1));
    await fixture.repository.setRecurringActive(paused.id, false);
    await createRecurring(fixture, local(2024, 1, 1), 'quarterly');
    await createRecurring(fixture, local(2024, 1, 1), 'daily');
    expect(await fixture.repository.postDueRecurring(new Date(2024, 0, 5, 12))).toBe(1 + 5);
    const items = await fixture.repository.getRecurringTransactions();
    expect(items.find((item) => item.frequency === 'quarterly')?.nextDueDate).toBe(local(2024, 4, 1));
    expect(items.find((item) => item.frequency === 'daily')?.nextDueDate).toBe(local(2024, 1, 6));
    expect(items.find((item) => item.id === paused.id)?.nextDueDate).toBe(local(2024, 1, 1));
  });

  test('caps catch-up at 24 occurrences per run', async () => {
    const fixture = await createFixture();
    await createRecurring(fixture, local(2020, 1, 1));
    const now = new Date(2024, 0, 15);
    expect(await fixture.repository.postDueRecurring(now)).toBe(24);
    expect((await fixture.repository.getRecurringTransactions())[0].nextDueDate).toBe(local(2022, 1, 1));
    expect(await fixture.repository.postDueRecurring(now)).toBe(24);
    expect(await fixture.repository.postDueRecurring(now)).toBe(1);
    expect(await fixture.repository.postDueRecurring(now)).toBe(0);
  });

  test('does not re-post an occurrence even if the schedule is rewound', async () => {
    const fixture = await createFixture();
    const recurring = await createRecurring(fixture, local(2024, 1, 10));
    expect(await fixture.repository.postDueRecurring(new Date(2024, 0, 20))).toBe(1);
    await fixture.repository.updateRecurring(recurring.id, { nextDueDate: local(2024, 1, 10) });
    expect(await fixture.repository.postDueRecurring(new Date(2024, 0, 20))).toBe(0);
    expect(await fixture.repository.getTransactions()).toHaveLength(1);
  });
});

const ids = async (fixture: Awaited<ReturnType<typeof createFixture>>) =>
  (await fixture.repository.getTransactions({ sort: 'date_asc' })).map((item) => item.id);

describe('review fixes', () => {
  test('deleting a loan payment reopens the loan and restores amount paid', async () => {
    const fixture = await createFixture();
    const loan = await createLoan(fixture.repository, 'taken');
    await fixture.repository.recordLoanPayment(loan.id, 500, fixture.account.id);
    let [saved] = await fixture.repository.getLoans();
    expect(saved.amountPaid).toBe(500);
    expect(saved.isClosed).toBe(true);
    const [payment] = await fixture.repository.getTransactions();
    await fixture.repository.deleteTransaction(payment.id);
    [saved] = await fixture.repository.getLoans();
    expect(saved.amountPaid).toBe(0);
    expect(saved.isClosed).toBe(false);
    expect(await balanceOf(fixture.repository, fixture.account.id)).toBe(0);
  });

  test('recurring occurrences get the same id on every device', async () => {
    const deviceA = await createFixture();
    const deviceB = await createFixture();
    const start = local(2024, 1, 5);
    const recurringA = await createRecurring(deviceA, start);
    await deviceB.database.runAsync(
      `INSERT INTO recurring_transactions (id, title, amount, type, category_id, account_id, frequency, start_date, next_due_date, is_active, updated_at)
       VALUES (?, 'Rent', 1000, 'expense', ?, ?, 'monthly', ?, ?, 1, ?)`,
      recurringA.id,
      deviceB.expense.id,
      deviceB.account.id,
      start,
      start,
      start,
    );
    await deviceA.repository.postDueRecurring(new Date(2024, 1, 10));
    await deviceB.repository.postDueRecurring(new Date(2024, 1, 10));
    expect(await ids(deviceA)).toHaveLength(2);
    expect(await ids(deviceA)).toEqual(await ids(deviceB));
  });
});
