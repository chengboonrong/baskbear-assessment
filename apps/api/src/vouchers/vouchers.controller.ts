import { Body, Controller, Get, Post, UseGuards, UseInterceptors } from '@nestjs/common';
import { z } from 'zod';
import { CognitoJwtGuard } from '../auth/cognito-jwt.guard';
import { CountryInterceptor } from '../countries/country.interceptor';
import { CurrentCountry, CurrentUser } from '../common/decorators';
import type { AuthContext, CountryContext } from '../common/types';
import { VoucherService } from './voucher.service';
import { CartService } from '../cart/cart.service';

const ValidateBody = z.object({
  code: z.string().min(1).max(32),
});

@Controller('v1/vouchers')
@UseInterceptors(CountryInterceptor)
export class VouchersController {
  constructor(
    private readonly vouchers: VoucherService,
    private readonly cart: CartService,
  ) {}

  @Get()
  list(@CurrentCountry() country: CountryContext) {
    return this.vouchers.listForCountry(country);
  }

  @Post('validate')
  @UseGuards(CognitoJwtGuard)
  async validate(
    @Body() raw: unknown,
    @CurrentUser() user: AuthContext,
    @CurrentCountry() country: CountryContext,
  ) {
    const body = ValidateBody.parse(raw);
    const cart = await this.cart.getCart(user.userId, country);
    const subtotal = cart.items.reduce((acc, it) => acc + it.lineTotalMinor, 0);
    const v = await this.vouchers.validate(body.code, user.userId, country, subtotal);
    return { code: v.code, discountMinor: v.discountMinor, subtotalMinor: subtotal };
  }
}
