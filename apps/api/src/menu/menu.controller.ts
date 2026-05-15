import { Controller, Get, Param, ParseIntPipe, Query, UseInterceptors } from '@nestjs/common';
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
  ) {
    return this.menu.list(country, category);
  }

  @Get(':id')
  findOne(
    @Param('id', ParseIntPipe) id: number,
    @CurrentCountry() country: CountryContext,
  ) {
    return this.menu.findOne(id, country);
  }
}
