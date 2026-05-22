/**
 * Pure pricing helpers.
 *
 * Everything is in minor units (cents/satang). No floats anywhere.
 * Basis points (1bp = 0.01%) are used for percentages: 600bps = 6.00%.
 */

export interface CustomisationChoice {
  groupSlug: string;
  optionSlug: string;
  name: string;
  deltaMinor: number;
}

export function computeLineTotal(
  baseUnitPriceMinor: number,
  customisations: CustomisationChoice[],
  quantity: number,
): number {
  const deltaSum = customisations.reduce((acc, c) => acc + c.deltaMinor, 0);
  const unitTotal = baseUnitPriceMinor + deltaSum;
  return unitTotal * Math.max(1, quantity);
}

export function applyTax(
  subtotalMinusDiscountMinor: number,
  taxRateBps: number,
): number {
  // Rounded half-up to nearest minor unit.
  return Math.round((subtotalMinusDiscountMinor * taxRateBps) / 10000);
}

export type VoucherKind = 'PERCENT' | 'FIXED';
export interface VoucherSpec {
  kind: VoucherKind;
  /** For PERCENT: basis points. For FIXED: minor units. */
  value: number;
  /** Cap for percent voucher (minor units), or null. */
  maxDiscountMinor: number | null;
}

export function computeVoucherDiscount(
  subtotalMinor: number,
  voucher: VoucherSpec,
): number {
  let raw = 0;
  if (voucher.kind === 'PERCENT') {
    raw = Math.floor((subtotalMinor * voucher.value) / 10000);
  } else {
    raw = voucher.value;
  }
  if (voucher.maxDiscountMinor !== null)
    raw = Math.min(raw, voucher.maxDiscountMinor);
  // Never discount more than the subtotal.
  return Math.max(0, Math.min(raw, subtotalMinor));
}
