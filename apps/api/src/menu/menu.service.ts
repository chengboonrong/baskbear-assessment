import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { CountryContext } from '../common/types';

export interface MenuItemDto {
  id: number;
  sku: string;
  name: string;
  description: string | null;
  category: { slug: string; name: string };
  priceMinor: number;
  currencyCode: string;
  isAvailable: boolean;
  dietaryTags: string[];
  imageUrl: string | null;
}

export interface MenuItemDetailDto extends MenuItemDto {
  customisationGroups: Array<{
    slug: string;
    name: string;
    minSelect: number;
    maxSelect: number;
    options: Array<{
      slug: string;
      name: string;
      priceDeltaMinor: number;
    }>;
  }>;
}

@Injectable()
export class MenuService {
  constructor(private readonly prisma: PrismaService) {}

  async list(
    country: CountryContext,
    categorySlug?: string,
  ): Promise<MenuItemDto[]> {
    const items = await this.prisma.menuItem.findMany({
      where: {
        isPublished: true,
        ...(categorySlug ? { category: { slug: categorySlug } } : {}),
      },
      orderBy: [{ category: { sortOrder: 'asc' } }, { id: 'asc' }],
      include: {
        category: {
          include: {
            translations: { where: { localeId: country.localeId } },
          },
        },
        translations: { where: { localeId: country.localeId } },
        countryPrices: { where: { countryId: country.countryId } },
      },
    });
    return items
      .filter((i) => i.countryPrices.length > 0)
      .map((i) => this.toDto(i, country));
  }

  async findOne(
    id: number,
    country: CountryContext,
  ): Promise<MenuItemDetailDto> {
    const item = await this.prisma.menuItem.findUnique({
      where: { id },
      include: {
        category: {
          include: { translations: { where: { localeId: country.localeId } } },
        },
        translations: { where: { localeId: country.localeId } },
        countryPrices: { where: { countryId: country.countryId } },
        customGroups: {
          orderBy: { sortOrder: 'asc' },
          include: {
            group: {
              include: {
                translations: { where: { localeId: country.localeId } },
                options: {
                  include: {
                    translations: { where: { localeId: country.localeId } },
                    countryPrices: { where: { countryId: country.countryId } },
                  },
                },
              },
            },
          },
        },
      },
    });
    if (!item || !item.isPublished || item.countryPrices.length === 0) {
      throw new NotFoundException(
        `Menu item ${id} not available in ${country.countryCode}`,
      );
    }
    const base = this.toDto(item, country);
    return {
      ...base,
      customisationGroups: item.customGroups.map((mg) => ({
        slug: mg.group.slug,
        name: mg.group.translations[0]?.name ?? mg.group.slug,
        minSelect: mg.group.minSelect,
        maxSelect: mg.group.maxSelect,
        options: mg.group.options.map((opt) => ({
          slug: opt.slug,
          name: opt.translations[0]?.name ?? opt.slug,
          // Country override > default delta. Cleaner than a join coalesce in SQL.
          priceDeltaMinor:
            opt.countryPrices[0]?.priceDeltaMinor ?? opt.priceDeltaMinor,
        })),
      })),
    };
  }

  private toDto(
    i: {
      id: number;
      sku: string;
      baseImageUrl: string | null;
      dietaryTags: unknown;
      translations: Array<{ name: string; description: string | null }>;
      countryPrices: Array<{ priceMinor: number; isAvailable: boolean }>;
      category: { slug: string; translations: Array<{ name: string }> };
    },
    country: CountryContext,
  ): MenuItemDto {
    const tr = i.translations[0];
    const price = i.countryPrices[0];
    return {
      id: i.id,
      sku: i.sku,
      name: tr?.name ?? i.sku,
      description: tr?.description ?? null,
      category: {
        slug: i.category.slug,
        name: i.category.translations[0]?.name ?? i.category.slug,
      },
      priceMinor: price.priceMinor,
      currencyCode: country.currencyCode,
      isAvailable: price.isAvailable,
      dietaryTags: Array.isArray(i.dietaryTags)
        ? (i.dietaryTags as string[])
        : [],
      imageUrl: i.baseImageUrl,
    };
  }
}
