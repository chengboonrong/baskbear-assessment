import { Module } from '@nestjs/common';
import { CountriesController } from './countries.controller';
import { CountryInterceptor } from './country.interceptor';

@Module({
  controllers: [CountriesController],
  providers: [CountryInterceptor],
  exports: [CountryInterceptor],
})
export class CountriesModule {}
