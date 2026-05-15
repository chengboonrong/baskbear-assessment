import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Observable } from 'rxjs';
import { PrismaService } from '../prisma/prisma.service';
import { RequestWithContext } from '../common/types';

/**
 * Resolves country + locale from `X-Country` / `X-Locale` headers (or query
 * fallbacks), validates them against the DB, and attaches a `CountryContext`
 * to the request.
 *
 * Resolution order for country:
 *   1. `X-Country` header
 *   2. `?country=` query string
 *   3. Authenticated user's `defaultCountry`
 *   4. `DEFAULT_COUNTRY_CODE` env
 *
 * Locale similarly, scoped to that country's allowed locales.
 *
 * Cached in-memory because the table is tiny and rarely changes.
 */
@Injectable()
export class CountryInterceptor implements NestInterceptor {
  private cache?: Promise<CountryLookup>;
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  async intercept(ctx: ExecutionContext, next: CallHandler): Promise<Observable<unknown>> {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    const lookup = await this.getLookup();

    const headerCountry = (req.header('x-country') as string | undefined)?.toUpperCase();
    const queryCountry  = (req.query?.country as string | undefined)?.toUpperCase();
    const userDefault   = req.auth ? lookup.userDefaults[req.auth.userId]?.country : undefined;
    const envDefault    = (this.config.get<string>('DEFAULT_COUNTRY_CODE') ?? 'MY').toUpperCase();

    const countryCode = [headerCountry, queryCountry, userDefault, envDefault]
      .find((c) => c && lookup.byCode[c]);
    const country = lookup.byCode[countryCode!];

    const headerLocale = (req.header('x-locale') as string | undefined)?.toLowerCase();
    const queryLocale  = (req.query?.locale as string | undefined)?.toLowerCase();
    const userLocale   = req.auth ? lookup.userDefaults[req.auth.userId]?.locale : undefined;
    const allowedLocales = country.locales;
    const localeCode = [headerLocale, queryLocale, userLocale, country.defaultLocale]
      .find((l) => l && allowedLocales[l]) ?? country.defaultLocale;

    req.country = {
      countryId:    country.id,
      countryCode:  country.code,
      currencyCode: country.currencyCode,
      taxRateBps:   country.taxRateBps,
      localeCode,
      localeId:     allowedLocales[localeCode],
    };
    return next.handle();
  }

  private async getLookup(): Promise<CountryLookup> {
    if (!this.cache) this.cache = this.buildLookup();
    return this.cache;
  }

  private async buildLookup(): Promise<CountryLookup> {
    const [countries, locales, links, users] = await Promise.all([
      this.prisma.country.findMany({ where: { isActive: true } }),
      this.prisma.locale.findMany(),
      this.prisma.countryLocale.findMany(),
      this.prisma.user.findMany({
        select: {
          id: true,
          defaultCountry: { select: { code: true } },
          defaultLocale:  { select: { code: true } },
        },
      }),
    ]);
    const localeById = Object.fromEntries(locales.map((l) => [l.id, l.code]));
    const byCode: Record<string, CountryRow> = {};
    for (const c of countries) {
      byCode[c.code] = {
        id: c.id, code: c.code, currencyCode: c.currencyCode,
        taxRateBps: c.taxRateBps, defaultLocale: c.defaultLocale, locales: {},
      };
    }
    for (const link of links) {
      const country = countries.find((c) => c.id === link.countryId);
      if (country) byCode[country.code].locales[localeById[link.localeId]] = link.localeId;
    }
    const userDefaults: Record<number, { country?: string; locale?: string }> = {};
    for (const u of users) {
      userDefaults[u.id] = {
        country: u.defaultCountry?.code,
        locale:  u.defaultLocale?.code,
      };
    }
    return { byCode, userDefaults };
  }
}

interface CountryRow {
  id: number; code: string; currencyCode: string;
  taxRateBps: number; defaultLocale: string;
  locales: Record<string, number>;
}
interface CountryLookup {
  byCode: Record<string, CountryRow>;
  userDefaults: Record<number, { country?: string; locale?: string }>;
}
