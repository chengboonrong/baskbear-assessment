import {
  applyTax,
  computeLineTotal,
  computeVoucherDiscount,
} from './pricing';

describe('computeLineTotal', () => {
  it('sums base + customisation deltas × quantity', () => {
    // Latte (1200) + Large (+400) + Oat (+250) = 1850 per unit, × 2 = 3700.
    expect(
      computeLineTotal(
        1200,
        [
          { groupSlug: 'size',  optionSlug: 'L',   name: 'Large', deltaMinor: 400 },
          { groupSlug: 'milk',  optionSlug: 'oat', name: 'Oat',   deltaMinor: 250 },
        ],
        2,
      ),
    ).toBe(3700);
  });

  it('treats quantity<1 as 1 (defensive)', () => {
    expect(computeLineTotal(1000, [], 0)).toBe(1000);
  });
});

describe('applyTax', () => {
  it('rounds half-up to the nearest minor unit', () => {
    // 6% of 3330 = 199.8 → 200
    expect(applyTax(3330, 600)).toBe(200);
    // 7% of 1500 = 105
    expect(applyTax(1500, 700)).toBe(105);
  });

  it('returns 0 when there is no taxable amount', () => {
    expect(applyTax(0, 600)).toBe(0);
  });
});

describe('computeVoucherDiscount', () => {
  it('caps a PERCENT voucher at maxDiscountMinor', () => {
    // 10% of 10000 = 1000, but max is 500 → 500.
    expect(
      computeVoucherDiscount(10000, { kind: 'PERCENT', value: 1000, maxDiscountMinor: 500 }),
    ).toBe(500);
  });

  it('applies a PERCENT voucher when below the cap', () => {
    // 10% of 3700 = 370.
    expect(
      computeVoucherDiscount(3700, { kind: 'PERCENT', value: 1000, maxDiscountMinor: 500 }),
    ).toBe(370);
  });

  it('applies a FIXED voucher exactly', () => {
    expect(
      computeVoucherDiscount(2500, { kind: 'FIXED', value: 500, maxDiscountMinor: null }),
    ).toBe(500);
  });

  it('never discounts more than the subtotal', () => {
    // RM 1 off on a RM 0.30 cart → discount capped at 30, not 100.
    expect(
      computeVoucherDiscount(30, { kind: 'FIXED', value: 100, maxDiscountMinor: null }),
    ).toBe(30);
  });
});
