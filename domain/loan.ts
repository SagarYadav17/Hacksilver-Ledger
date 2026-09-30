import Decimal from 'decimal.js-light';

/** Amortized monthly instalment: P·r·(1+r)^n / ((1+r)^n − 1), r = annual% / 12 / 100. */
export function calculateEmi(principal: number, annualRatePct: number, months: number): number {
  if (!(principal > 0) || !(months > 0) || !Number.isFinite(principal) || !Number.isFinite(annualRatePct)) return 0;
  const p = new Decimal(principal);
  if (annualRatePct <= 0) return p.div(months).toDecimalPlaces(2).toNumber();
  const r = new Decimal(annualRatePct).div(1200);
  const growth = r.plus(1).pow(months);
  return p.mul(r).mul(growth).div(growth.minus(1)).toDecimalPlaces(2).toNumber();
}
