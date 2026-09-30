import type { Frequency } from './types';

const MONTHS: Record<Exclude<Frequency, 'daily'>, number> = { monthly: 1, quarterly: 3, yearly: 12 };

/** Next occurrence after `due`, keeping the day-of-month anchored to `anchor` (clamped to month end). */
export function advanceDueDate(due: string, frequency: Frequency, anchor: string): string {
  const date = new Date(due);
  if (frequency === 'daily') {
    date.setDate(date.getDate() + 1);
    return date.toISOString();
  }
  const target = new Date(
    date.getFullYear(),
    date.getMonth() + MONTHS[frequency],
    1,
    date.getHours(),
    date.getMinutes(),
    date.getSeconds(),
    date.getMilliseconds(),
  );
  const lastDay = new Date(target.getFullYear(), target.getMonth() + 1, 0).getDate();
  target.setDate(Math.min(new Date(anchor).getDate(), lastDay));
  return target.toISOString();
}
