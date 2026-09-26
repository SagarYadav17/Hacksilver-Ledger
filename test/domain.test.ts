import { describe, expect, test } from 'bun:test';
import { formatCurrency, titleCase } from '../lib/format';
import { newId } from '../domain/types';

describe('ledger domain helpers', () => {
  test('creates stable-looking unique local ids', () => {
    const first = newId();
    const second = newId();
    expect(first).not.toBe(second);
    expect(first.length).toBeGreaterThan(8);
  });

  test('formats currency with decimal-safe rounding and private mode', () => {
    expect(formatCurrency(1234.567)).toBe('₹1,234.57');
    expect(formatCurrency(1234.567, 'USD')).toBe('$1,234.57');
    expect(formatCurrency(1234.567, 'INR', true)).toBe('••••••');
  });

  test('makes database enum values readable', () => {
    expect(titleCase('credit_card')).toBe('Credit Card');
  });
});
