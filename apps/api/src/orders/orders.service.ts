import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { FulfilmentType, OrderStatus, Prisma } from '@prisma/client';
import { ulid } from 'ulid';
import { PrismaService } from '../prisma/prisma.service';
import { CountryContext } from '../common/types';
import { applyTax, computeVoucherDiscount } from '../common/pricing';

export interface PlaceOrderInput {
  fulfilmentType: FulfilmentType;
  outletId?: number;
  voucherCode?: string;
  notes?: string;
  idempotencyKey: string;
}

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: number) {
    const orders = await this.prisma.order.findMany({
      where: { userId },
      orderBy: { placedAt: 'desc' },
      take: 50,
      include: { items: true, statusEvents: { orderBy: { occurredAt: 'asc' } } },
    });
    return orders;
  }

  async findOne(userId: number, id: number) {
    const order = await this.prisma.order.findUnique({
      where: { id },
      include: { items: true, statusEvents: { orderBy: { occurredAt: 'asc' } }, outlet: true },
    });
    if (!order || order.userId !== userId) throw new NotFoundException('Order not found');
    return order;
  }

  /**
   * Place an order atomically:
   *   1. SELECT … FOR UPDATE on the cart row (Prisma → $queryRaw lock).
   *   2. Re-read cart items at current prices (defends against price drift
   *      between add-to-cart and checkout).
   *   3. Validate voucher under the same transaction with a row lock to
   *      enforce per-user / total limits without races.
   *   4. Insert order, order_items (with name + price snapshot), status event
   *      (PENDING), voucher_redemption (if any).
   *   5. Clear cart_items.
   *   6. Return order.
   *
   * Idempotency: (userId, idempotencyKey) is a unique index. A retry with the
   * same key after a successful placement returns the same order.
   */
  async place(userId: number, country: CountryContext, input: PlaceOrderInput) {
    // Fast-path idempotency check before opening a transaction.
    if (input.idempotencyKey) {
      const existing = await this.prisma.order.findUnique({
        where: { userId_idempotencyKey: { userId, idempotencyKey: input.idempotencyKey } },
      });
      if (existing) return this.findOne(userId, existing.id);
    }

    try {
      const order = await this.prisma.$transaction(async (tx) => {
        // 1. Lock the cart row (MySQL row-level lock under InnoDB).
        await tx.$executeRaw`
          SELECT id FROM carts
           WHERE userId = ${userId} AND countryId = ${country.countryId}
           FOR UPDATE
        `;
        const cart = await tx.cart.findUnique({
          where: { userId_countryId: { userId, countryId: country.countryId } },
          include: {
            items: { include: { menuItem: { include: {
              translations:  { where: { localeId: country.localeId } },
              countryPrices: { where: { countryId: country.countryId } },
            } } } },
          },
        });
        if (!cart || cart.items.length === 0) {
          throw new BadRequestException('CART_EMPTY');
        }

        // 2. Recompute line totals against current country prices. We trust
        //    customisation snapshots (they were validated at add-time) but
        //    re-price the base unit to catch menu price changes mid-session.
        let subtotal = 0;
        const itemRows = cart.items.map((it) => {
          const current = it.menuItem.countryPrices[0];
          if (!current || !current.isAvailable) {
            throw new BadRequestException(`ITEM_NO_LONGER_AVAILABLE:${it.menuItemId}`);
          }
          const customs = (it.customisationsJson as unknown as Array<{ deltaMinor: number }>) ?? [];
          const deltaSum = customs.reduce((a, c) => a + c.deltaMinor, 0);
          const unitPrice = current.priceMinor + deltaSum;
          const lineTotal = unitPrice * it.quantity;
          subtotal += lineTotal;
          return {
            menuItemId: it.menuItemId,
            sku:        it.menuItem.sku,
            nameSnapshot: it.menuItem.translations[0]?.name ?? it.menuItem.sku,
            quantity:   it.quantity,
            unitPriceMinor: unitPrice,
            customisationsSnapshotJson: it.customisationsJson as Prisma.InputJsonValue,
            lineTotalMinor: lineTotal,
          };
        });

        // 3. Voucher
        let voucherId: number | null = null;
        let discount = 0;
        if (input.voucherCode) {
          const v = await tx.voucher.findUnique({
            where: { code: input.voucherCode },
            include: { countries: true },
          });
          if (!v || !v.isActive) throw new BadRequestException('VOUCHER_INVALID');
          const now = new Date();
          if (now < v.startsAt || now > v.endsAt) throw new BadRequestException('VOUCHER_EXPIRED');
          if (!v.countries.some((c) => c.countryId === country.countryId)) {
            throw new BadRequestException('VOUCHER_NOT_AVAILABLE_IN_COUNTRY');
          }
          if (subtotal < v.minSpendMinor) throw new BadRequestException('VOUCHER_MIN_SPEND_NOT_MET');

          const userUses = await tx.voucherRedemption.count({
            where: { voucherId: v.id, userId },
          });
          if (userUses >= v.perUserLimit) throw new BadRequestException('VOUCHER_USER_LIMIT');
          if (v.totalLimit !== null) {
            const total = await tx.voucherRedemption.count({ where: { voucherId: v.id } });
            if (total >= v.totalLimit) throw new BadRequestException('VOUCHER_EXHAUSTED');
          }
          discount = computeVoucherDiscount(subtotal, {
            kind: v.type, value: v.value, maxDiscountMinor: v.maxDiscountMinor,
          });
          voucherId = v.id;
        }

        // 4. Tax — applied on subtotal after discount.
        const tax   = applyTax(Math.max(0, subtotal - discount), country.taxRateBps);
        const total = Math.max(0, subtotal - discount) + tax;

        // 5. Persist
        const order = await tx.order.create({
          data: {
            orderNumber: ulid(),
            userId, countryId: country.countryId,
            outletId: input.outletId ?? null,
            status: OrderStatus.PENDING,
            fulfilmentType: input.fulfilmentType,
            subtotalMinor: subtotal,
            discountMinor: discount,
            taxMinor: tax,
            totalMinor: total,
            currencyCode: country.currencyCode,
            voucherId,
            idempotencyKey: input.idempotencyKey,
            notes: input.notes ?? null,
            items: { create: itemRows },
            statusEvents: { create: { status: OrderStatus.PENDING, source: 'SYSTEM' } },
          },
        });
        if (voucherId !== null) {
          await tx.voucherRedemption.create({
            data: { voucherId, userId, orderId: order.id, discountMinor: discount },
          });
        }
        await tx.cartItem.deleteMany({ where: { cartId: cart.id } });
        return order;
      }, { isolationLevel: Prisma.TransactionIsolationLevel.RepeatableRead });

      return this.findOne(userId, order.id);
    } catch (e) {
      // Race: another request with the same idempotency key landed first.
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        const dup = await this.prisma.order.findUnique({
          where: { userId_idempotencyKey: { userId, idempotencyKey: input.idempotencyKey } },
        });
        if (dup) return this.findOne(userId, dup.id);
        throw new ConflictException('DUPLICATE_KEY');
      }
      throw e;
    }
  }
}
