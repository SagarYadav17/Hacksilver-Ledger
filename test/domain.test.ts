import { describe, expect, test } from 'bun:test';
import { formatCurrency, titleCase } from '../lib/format';
import { newId } from '../domain/types';
import { calculateEmi } from '../domain/loan';
import { advanceDueDate } from '../domain/recurring';

const local = (year: number, month: number, day: number) => new Date(year, month - 1, day).toISOString();

describe('ledger domain helpers', () => {
  test('creates stable-looking unique local ids', () => {
    const first = newId();
    const second = newId();
    expect(first).not.toBe(second);
    expect(first.length).toBeGreaterThan(8);
    expect(first).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
  });

  test('formats currency with decimal-safe rounding and private mode', () => {
    expect(formatCurrency(1234.567)).toBe('₹1,234.57');
    expect(formatCurrency(1234.567, 'USD')).toBe('$1,234.57');
    expect(formatCurrency(1234.567, 'INR', true)).toBe('••••••');
  });

  test('formats currency with a locale per currency', () => {
    expect(formatCurrency(1234567.8, 'INR')).toBe('₹12,34,567.80');
    expect(formatCurrency(1234567.8, 'USD')).toBe('$1,234,567.80');
    expect(formatCurrency(1234567.8, 'EUR')).toBe('€1,234,567.80');
    expect(formatCurrency(1234567.8, 'GBP')).toBe('£1,234,567.80');
    expect(formatCurrency(-5, 'USD')).toBe('-$5.00');
    expect(formatCurrency(5, 'USD', true)).toBe('••••••');
  });

  test('makes database enum values readable', () => {
    expect(titleCase('credit_card')).toBe('Credit Card');
  });

  test('calculates amortized EMI', () => {
    expect(calculateEmi(100000, 12, 12)).toBe(8884.88);
    expect(calculateEmi(500000, 8.5, 60)).toBe(10258.27);
    expect(calculateEmi(1200, 0, 12)).toBe(100);
    expect(calculateEmi(1000, 0, 3)).toBe(333.33);
    expect(calculateEmi(Number.NaN, 12, 12)).toBe(0);
    expect(calculateEmi(1000, 12, 0)).toBe(0);
  });

  test('advances due dates with month-end anchoring', () => {
    const anchor = local(2023, 1, 31);
    expect(advanceDueDate(local(2023, 1, 31), 'monthly', anchor)).toBe(local(2023, 2, 28));
    expect(advanceDueDate(local(2023, 2, 28), 'monthly', anchor)).toBe(local(2023, 3, 31));
    expect(advanceDueDate(local(2023, 11, 30), 'quarterly', anchor)).toBe(local(2024, 2, 29));
    expect(advanceDueDate(local(2024, 2, 29), 'yearly', local(2024, 2, 29))).toBe(local(2025, 2, 28));
    expect(advanceDueDate(local(2023, 12, 31), 'daily', anchor)).toBe(local(2024, 1, 1));
  });
});
