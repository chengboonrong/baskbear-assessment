import { BadRequestException, Injectable } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CountryContext } from '../common/types';
import { computeVoucherDiscount } from '../common/pricing';

export interface ValidatedVoucher {
  id: number;
  code: string;
  discountMinor: number;
}

@Injectable()
export class VoucherService {
  constructor(private readonly prisma: PrismaService) {}

  async listForCountry(country: CountryContext) {
    const now = new Date();
    const rows = await this.prisma.voucher.findMany({
      where: {
        isActive: true,
        startsAt: { lte: now },
        endsAt:   { gte: now },
        countries: { some: { countryId: country.countryId } },
      },
      orderBy: { endsAt: 'asc' },
    });
    return rows.map((v) => ({
      code: v.code,
      type: v.type,
      value: v.value,
      minSpendMinor: v.minSpendMinor,
      maxDiscountMinor: v.maxDiscountMinor,
      stackable: v.stackable,
      endsAt: v.endsAt,
    }));
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
    if (now < v.startsAt) throw new BadRequestException('VOUCHER_NOT_YET_ACTIVE');
    if (now > v.endsAt)   throw new BadRequestException('VOUCHER_EXPIRED');

    const allowed = await this.prisma.voucherCountry.findUnique({
      where: { voucherId_countryId: { voucherId: v.id, countryId: country.countryId } },
    });
    if (!allowed) throw new BadRequestException('VOUCHER_NOT_AVAILABLE_IN_COUNTRY');

    if (subtotalMinor < v.minSpendMinor) {
      throw new BadRequestException({ code: 'MIN_SPEND_NOT_MET', minSpendMinor: v.minSpendMinor });
    }

    const userUses = await this.prisma.voucherRedemption.count({
      where: { voucherId: v.id, userId },
    });
    if (userUses >= v.perUserLimit) throw new BadRequestException('VOUCHER_USER_LIMIT_REACHED');

    if (v.totalLimit !== null) {
      const total = await this.prisma.voucherRedemption.count({ where: { voucherId: v.id } });
      if (total >= v.totalLimit) throw new BadRequestException('VOUCHER_EXHAUSTED');
    }

    const discount = computeVoucherDiscount(subtotalMinor, {
      kind: v.type,
      value: v.value,
      maxDiscountMinor: v.maxDiscountMinor,
    });
    return { id: v.id, code: v.code, discountMinor: discount };
  }
}
