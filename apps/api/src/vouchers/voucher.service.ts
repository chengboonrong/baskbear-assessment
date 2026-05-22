import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CountryContext } from '../common/types';
import { computeVoucherDiscount } from '../common/pricing';
import { computeVoucherAvailability } from './voucher-availability';

export interface ValidatedVoucher {
  id: number;
  code: string;
  discountMinor: number;
}

@Injectable()
export class VoucherService {
  constructor(private readonly prisma: PrismaService) {}

  async listForCountry(country: CountryContext, userId?: number) {
    const now = new Date();
    const rows = await this.prisma.voucher.findMany({
      where: {
        isActive: true,
        startsAt: { lte: now },
        endsAt: { gte: now },
        countries: { some: { countryId: country.countryId } },
      },
      orderBy: { endsAt: 'asc' },
    });
    if (rows.length === 0) return [];

    // Redemption counts in two grouped queries (no N+1): total caps are
    // user-independent; per-user caps need the caller. Anonymous → user map
    // stays empty, so only FULLY_CLAIMED can ever surface.
    const ids = rows.map((v) => v.id);
    const totalByVoucher = await this.countRedemptions({ voucherId: { in: ids } });
    const userByVoucher =
      userId == null
        ? new Map<number, number>()
        : await this.countRedemptions({ voucherId: { in: ids }, userId });

    return rows.map((v) => {
      const { redeemable, unavailableReason } = computeVoucherAvailability(
        { perUserLimit: v.perUserLimit, totalLimit: v.totalLimit },
        {
          userRedemptions: userByVoucher.get(v.id) ?? 0,
          totalRedemptions: totalByVoucher.get(v.id) ?? 0,
        },
      );
      return {
        code: v.code,
        type: v.type,
        value: v.value,
        minSpendMinor: v.minSpendMinor,
        maxDiscountMinor: v.maxDiscountMinor,
        stackable: v.stackable,
        endsAt: v.endsAt,
        redeemable,
        unavailableReason,
      };
    });
  }

  /** Groups VoucherRedemption rows by voucherId → count, for the given filter. */
  private async countRedemptions(
    where: { voucherId: { in: number[] }; userId?: number },
  ): Promise<Map<number, number>> {
    const groups = await this.prisma.voucherRedemption.groupBy({
      by: ['voucherId'],
      where,
      _count: { _all: true },
    });
    return new Map(groups.map((g) => [g.voucherId, g._count._all]));
  }

  /**
   * Validates a voucher code against a (user, country, subtotal). Throws with
   * a structured reason on failure. Returns `{ id, code, discountMinor }`.
   *
   * NOTE: This is read-only validation. Atomic redemption (with per-user /
   * total-limit checks under a row lock) lives in OrdersService.placeOrder.
   */
  async validate(
    code: string,
    userId: number,
    country: CountryContext,
    subtotalMinor: number,
  ): Promise<ValidatedVoucher> {
    const v = await this.prisma.voucher.findUnique({ where: { code } });
    if (!v || !v.isActive) throw new BadRequestException('VOUCHER_INVALID');

    const now = new Date();
    if (now < v.startsAt)
      throw new BadRequestException('VOUCHER_NOT_YET_ACTIVE');
    if (now > v.endsAt) throw new BadRequestException('VOUCHER_EXPIRED');

    const allowed = await this.prisma.voucherCountry.findUnique({
      where: {
        voucherId_countryId: { voucherId: v.id, countryId: country.countryId },
      },
    });
    if (!allowed)
      throw new BadRequestException('VOUCHER_NOT_AVAILABLE_IN_COUNTRY');

    if (subtotalMinor < v.minSpendMinor) {
      throw new BadRequestException({
        code: 'MIN_SPEND_NOT_MET',
        minSpendMinor: v.minSpendMinor,
      });
    }

    const userUses = await this.prisma.voucherRedemption.count({
      where: { voucherId: v.id, userId },
    });
    if (userUses >= v.perUserLimit)
      throw new BadRequestException('VOUCHER_USER_LIMIT_REACHED');

    if (v.totalLimit !== null) {
      const total = await this.prisma.voucherRedemption.count({
        where: { voucherId: v.id },
      });
      if (total >= v.totalLimit)
        throw new BadRequestException('VOUCHER_EXHAUSTED');
    }

    const discount = computeVoucherDiscount(subtotalMinor, {
      kind: v.type,
      value: v.value,
      maxDiscountMinor: v.maxDiscountMinor,
    });
    return { id: v.id, code: v.code, discountMinor: discount };
  }
}
