/**
 * Why a voucher can't be redeemed by the current caller. Surfaced to the
 * client so the Offers list can grey the card out with a precise label.
 */
export type VoucherUnavailableReason = 'ALREADY_USED' | 'FULLY_CLAIMED';

export interface VoucherAvailability {
  redeemable: boolean;
  unavailableReason: VoucherUnavailableReason | null;
}

/**
 * Pure redeemability check for the *list* surface — redemption limits only.
 * Min-spend is cart-dependent and handled at validate/checkout, not here.
 *
 * The per-user limit is checked first: "you've already used this" is more
 * relevant to the caller than a global "fully claimed". For anonymous callers
 * pass `userRedemptions: 0`, which can only ever surface FULLY_CLAIMED (a
 * user-independent fact).
 */
export function computeVoucherAvailability(
  limits: { perUserLimit: number; totalLimit: number | null },
  counts: { userRedemptions: number; totalRedemptions: number },
): VoucherAvailability {
  if (counts.userRedemptions >= limits.perUserLimit) {
    return { redeemable: false, unavailableReason: 'ALREADY_USED' };
  }
  if (limits.totalLimit !== null && counts.totalRedemptions >= limits.totalLimit) {
    return { redeemable: false, unavailableReason: 'FULLY_CLAIMED' };
  }
  return { redeemable: true, unavailableReason: null };
}
