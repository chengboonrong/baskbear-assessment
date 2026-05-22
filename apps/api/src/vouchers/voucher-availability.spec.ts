import { computeVoucherAvailability } from './voucher-availability';

describe('computeVoucherAvailability', () => {
  it('is redeemable when the caller is under both limits', () => {
    expect(
      computeVoucherAvailability(
        { perUserLimit: 1, totalLimit: null },
        { userRedemptions: 0, totalRedemptions: 5 },
      ),
    ).toEqual({ redeemable: true, unavailableReason: null });
  });

  it('flags ALREADY_USED when the caller hit their per-user limit', () => {
    // WELCOME10: perUserLimit 1, the demo user already redeemed it once.
    expect(
      computeVoucherAvailability(
        { perUserLimit: 1, totalLimit: null },
        { userRedemptions: 1, totalRedemptions: 1 },
      ),
    ).toEqual({ redeemable: false, unavailableReason: 'ALREADY_USED' });
  });

  it('flags FULLY_CLAIMED when the total cap is reached', () => {
    // MY5OFF: totalLimit 1000, caller has uses left but the pool is drained.
    expect(
      computeVoucherAvailability(
        { perUserLimit: 3, totalLimit: 1000 },
        { userRedemptions: 1, totalRedemptions: 1000 },
      ),
    ).toEqual({ redeemable: false, unavailableReason: 'FULLY_CLAIMED' });
  });

  it('prefers the per-user reason over the global one', () => {
    expect(
      computeVoucherAvailability(
        { perUserLimit: 1, totalLimit: 1000 },
        { userRedemptions: 1, totalRedemptions: 1000 },
      ).unavailableReason,
    ).toBe('ALREADY_USED');
  });

  it('anonymous callers (userRedemptions 0) can only ever see FULLY_CLAIMED', () => {
    expect(
      computeVoucherAvailability(
        { perUserLimit: 1, totalLimit: null },
        { userRedemptions: 0, totalRedemptions: 999 },
      ),
    ).toEqual({ redeemable: true, unavailableReason: null });

    expect(
      computeVoucherAvailability(
        { perUserLimit: 1, totalLimit: 10 },
        { userRedemptions: 0, totalRedemptions: 10 },
      ).unavailableReason,
    ).toBe('FULLY_CLAIMED');
  });
});
