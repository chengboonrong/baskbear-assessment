import {
  Controller,
  Get,
  Param,
  ParseIntPipe,
  Query,
  UseInterceptors,
} from '@nestjs/common';
import { CountryInterceptor } from '../countries/country.interceptor';
import { CurrentCountry } from '../common/decorators';
import type { CountryContext } from '../common/types';
import { MenuService } from './menu.service';

@Controller('v1/menu')
@UseInterceptors(CountryInterceptor)
export class MenuController {
  constructor(private readonly menu: MenuService) {}

  @Get()
  list(
    @CurrentCountry() country: CountryContext,
    @Query('category') category?: string,
    @Query('outlet') outlet?: string,
  ) {
    return this.menu.list(country, category, parseOutletId(outlet));
  }

  @Get(':id')
  findOne(
    @Param('id', ParseIntPipe) id: number,
    @CurrentCountry() country: CountryContext,
    @Query('outlet') outlet?: string,
  ) {
    return this.menu.findOne(id, country, parseOutletId(outlet));
  }
}

/** `?outlet=` → positive int, or undefined when absent/invalid (menu falls back
 * to country-wide availability). */
function parseOutletId(raw?: string): number | undefined {
  if (raw === undefined) return undefined;
  const n = Number.parseInt(raw, 10);
  return Number.isInteger(n) && n > 0 ? n : undefined;
}
