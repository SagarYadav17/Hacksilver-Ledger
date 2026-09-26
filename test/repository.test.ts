import { Database } from 'bun:sqlite';
import { describe, expect, test } from 'bun:test';
import type { SQLiteDatabase } from 'expo-sqlite';
import { initializeDatabase } from '../data/schema';
import { LedgerRepository } from '../data/repository';

class MemoryDatabase {
  private readonly database = new Database(':memory:');

  async execAsync(source: string): Promise<void> {
    this.database.exec(source);
  }

  async runAsync(source: string, ...params: Array<string | number | null>): Promise<void> {
    this.database.query(source).run(...params);
  }

  async getFirstAsync<T>(source: string, ...params: Array<string | number | null>): Promise<T | null> {
    return (this.database.query(source).get(...params) as T | undefined) ?? null;
  }

  async getAllAsync<T>(source: string, ...params: Array<string | number | null>): Promise<T[]> {
    return this.database.query(source).all(...params) as T[];
  }

  async withTransactionAsync<T>(task: () => Promise<T>): Promise<T> {
    this.database.exec('BEGIN');
    try {
      const result = await task();
      this.database.exec('COMMIT');
      return result;
    } catch (error) {
      this.database.exec('ROLLBACK');
      throw error;
    }
  }
}

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
