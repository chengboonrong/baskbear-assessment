import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { CountryContext } from '../common/types';
import { computeLineTotal, CustomisationChoice } from '../common/pricing';

export interface AddItemInput {
  menuItemId: number;
  quantity: number;
  /** [{ groupSlug, optionSlug }, ...] */
  customisations: Array<{ groupSlug: string; optionSlug: string }>;
}

@Injectable()
export class CartService {
  constructor(private readonly prisma: PrismaService) {}

  async getCart(userId: number, country: CountryContext) {
    const cart = await this.ensureCart(userId, country);
    const items = await this.prisma.cartItem.findMany({
      where: { cartId: cart.id },
      orderBy: { id: 'asc' },
      include: {
        menuItem: {
          include: {
            translations: { where: { localeId: country.localeId } },
          },
        },
      },
    });
    const subtotal = items.reduce((acc, it) => acc + it.lineTotalMinor, 0);
    return {
      id: cart.id,
      currencyCode: cart.currencyCode,
      country: country.countryCode,
      items: items.map((it) => ({
        id: it.id,
        menuItemId: it.menuItemId,
        name: it.menuItem.translations[0]?.name ?? it.menuItem.sku,
        quantity: it.quantity,
        unitPriceMinor: it.unitPriceMinor,
        customisations: (it.customisationsJson as unknown as CustomisationChoice[]) ?? [],
        lineTotalMinor: it.lineTotalMinor,
      })),
      subtotalMinor: subtotal,
    };
  }

  async addItem(userId: number, country: CountryContext, input: AddItemInput) {
    if (input.quantity < 1) throw new BadRequestException('QUANTITY_INVALID');
    const cart = await this.ensureCart(userId, country);
    const { basePrice, customisations } = await this.resolvePricing(input, country);
    const lineTotal = computeLineTotal(basePrice, customisations, input.quantity);
    await this.prisma.cartItem.create({
      data: {
        cartId: cart.id,
        menuItemId: input.menuItemId,
        quantity: input.quantity,
        unitPriceMinor: basePrice + customisations.reduce((a, c) => a + c.deltaMinor, 0),
        customisationsJson: customisations as unknown as Prisma.InputJsonValue,
        lineTotalMinor: lineTotal,
      },
    });
    return this.getCart(userId, country);
  }

  async updateQuantity(userId: number, country: CountryContext, cartItemId: number, quantity: number) {
    if (quantity < 1) return this.removeItem(userId, country, cartItemId);
    const cart = await this.ensureCart(userId, country);
    const item = await this.prisma.cartItem.findUnique({ where: { id: cartItemId } });
    if (!item || item.cartId !== cart.id) throw new NotFoundException('Cart item not found');
    await this.prisma.cartItem.update({
      where: { id: cartItemId },
      data: {
        quantity,
        lineTotalMinor: item.unitPriceMinor * quantity,
      },
    });
    return this.getCart(userId, country);
  }

  async removeItem(userId: number, country: CountryContext, cartItemId: number) {
    const cart = await this.ensureCart(userId, country);
    await this.prisma.cartItem.deleteMany({
      where: { id: cartItemId, cartId: cart.id },
    });
    return this.getCart(userId, country);
  }

  /** Used by orders service after a successful placement. */
  async clear(cartId: number) {
    await this.prisma.cartItem.deleteMany({ where: { cartId } });
  }

  async ensureCart(userId: number, country: CountryContext) {
    return this.prisma.cart.upsert({
      where: { userId_countryId: { userId, countryId: country.countryId } },
      update: {},
      create: {
        userId,
        countryId: country.countryId,
        currencyCode: country.currencyCode,
      },
    });
  }

  /**
   * Looks up the menu item's current country price + validates customisations
   * against allowed groups. Returns the base price and a flattened snapshot of
   * choices including country-aware deltas + locale-aware names.
   */
  async resolvePricing(input: AddItemInput, country: CountryContext) {
    const item = await this.prisma.menuItem.findUnique({
      where: { id: input.menuItemId },
      include: {
        countryPrices: { where: { countryId: country.countryId } },
        customGroups: {
          include: {
            group: {
              include: {
                options: {
                  include: {
                    translations:  { where: { localeId: country.localeId } },
                    countryPrices: { where: { countryId: country.countryId } },
                  },
                },
              },
            },
          },
        },
      },
    });
    if (!item || !item.isPublished) throw new NotFoundException('MENU_ITEM_NOT_FOUND');
    if (item.countryPrices.length === 0 || !item.countryPrices[0].isAvailable) {
      throw new BadRequestException('ITEM_NOT_AVAILABLE_IN_COUNTRY');
    }
    const basePrice = item.countryPrices[0].priceMinor;

    const allowedBySlug = new Map<string, typeof item.customGroups[number]>();
    for (const mg of item.customGroups) allowedBySlug.set(mg.group.slug, mg);

    const choices: CustomisationChoice[] = [];
    for (const c of input.customisations) {
      const group = allowedBySlug.get(c.groupSlug);
      if (!group) throw new BadRequestException(`CUSTOM_GROUP_NOT_ALLOWED:${c.groupSlug}`);
      const opt = group.group.options.find((o) => o.slug === c.optionSlug);
      if (!opt) throw new BadRequestException(`CUSTOM_OPTION_NOT_FOUND:${c.optionSlug}`);
      const delta = opt.countryPrices[0]?.priceDeltaMinor ?? opt.priceDeltaMinor;
      choices.push({
        groupSlug: c.groupSlug,
        optionSlug: c.optionSlug,
        name: opt.translations[0]?.name ?? opt.slug,
        deltaMinor: delta,
      });
    }
    // Required groups must be present.
    for (const mg of item.customGroups) {
      const provided = choices.filter((ch) => ch.groupSlug === mg.group.slug).length;
      if (provided < mg.group.minSelect || provided > mg.group.maxSelect) {
        throw new BadRequestException(`CUSTOM_GROUP_SELECTION_INVALID:${mg.group.slug}`);
      }
    }
    return { basePrice, customisations: choices };
  }
}
