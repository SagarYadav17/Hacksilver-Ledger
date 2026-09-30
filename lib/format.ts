import Decimal from 'decimal.js-light';

const CURRENCY_LOCALES: Record<string, string> = { INR: 'en-IN', USD: 'en-US', EUR: 'en-IE', GBP: 'en-GB' };

export function formatCurrency(value: number, currency = 'INR', hidden = false): string {
  if (hidden) return '••••••';
  const amount = new Decimal(value).toDecimalPlaces(2).toNumber();
  const options = { minimumFractionDigits: 2, maximumFractionDigits: 2 };
  try {
    return new Intl.NumberFormat(CURRENCY_LOCALES[currency] ?? 'en-US', {
      ...options,
      style: 'currency',
      currency,
    }).format(amount);
  } catch {
    return `${currency} ${amount.toLocaleString('en-US', options)}`;
  }
}

export function formatDate(
  value: string,
  options: Intl.DateTimeFormatOptions = { day: 'numeric', month: 'short' },
): string {
  return new Date(value).toLocaleDateString('en-IN', options);
}

export function formatRelativeDate(value: string): string {
  const date = new Date(value);
  const today = new Date();
  const sameDay = date.toDateString() === today.toDateString();
  if (sameDay) return 'Today';
  const yesterday = new Date(today);
  yesterday.setDate(today.getDate() - 1);
  if (date.toDateString() === yesterday.toDateString()) return 'Yesterday';
  return formatDate(value);
}

export function titleCase(value: string): string {
  return value.replace(/_/g, ' ').replace(/\b\w/g, (match) => match.toUpperCase());
}
