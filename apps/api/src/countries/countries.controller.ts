import { Controller, Get, Query } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';

@Controller('v1/countries')
export class CountriesController {
  constructor(private readonly prisma: PrismaService) {}

  @Get()
  async list() {
    const rows = await this.prisma.country.findMany({
      where: { isActive: true },
      orderBy: { name: 'asc' },
      include: {
        locales: {
          include: { locale: true },
        },
      },
    });
    return rows.map((c) => ({
      code: c.code,
      name: c.name,
      currencyCode: c.currencyCode,
      taxRateBps: c.taxRateBps,
      timezone: c.timezone,
      defaultLocale: c.defaultLocale,
      locales: c.locales.map((cl) => ({
        code: cl.locale.code,
        isDefault: cl.isDefault,
      })),
    }));
  }

  @Get('feature-flags')
  async featureFlags(@Query('country') countryCode?: string) {
    const country = countryCode
      ? await this.prisma.country.findUnique({ where: { code: countryCode.toUpperCase() } })
      : null;
    const flags = await this.prisma.featureFlag.findMany({
      where: {
        OR: [{ countryId: null }, ...(country ? [{ countryId: country.id }] : [])],
      },
      orderBy: [{ key: 'asc' }, { countryId: 'asc' }],
    });
    // Per-country flag wins over global.
    const merged: Record<string, boolean> = {};
    for (const f of flags) {
      if (f.countryId === null && merged[f.key] === undefined) merged[f.key] = f.isEnabled;
    }
    for (const f of flags) {
      if (f.countryId !== null) merged[f.key] = f.isEnabled;
    }
    return merged;
  }
}
