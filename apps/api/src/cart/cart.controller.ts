import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseIntPipe,
  Patch,
  Post,
  UseGuards,
  UseInterceptors,
} from '@nestjs/common';
import { z } from 'zod';
import { CognitoJwtGuard } from '../auth/cognito-jwt.guard';
import { CountryInterceptor } from '../countries/country.interceptor';
import { CurrentCountry, CurrentUser } from '../common/decorators';
import type { AuthContext, CountryContext } from '../common/types';
import { CartService } from './cart.service';

const AddItem = z.object({
  menuItemId: z.number().int().positive(),
  quantity: z.number().int().min(1).max(20),
  customisations: z
    .array(
      z.object({
        groupSlug: z.string().min(1),
        optionSlug: z.string().min(1),
      }),
    )
    .default([]),
});

const UpdateQty = z.object({
  quantity: z.number().int().min(0).max(20),
});

@Controller('v1/cart')
@UseGuards(CognitoJwtGuard)
@UseInterceptors(CountryInterceptor)
export class CartController {
  constructor(private readonly cart: CartService) {}

  @Get()
  get(@CurrentUser() u: AuthContext, @CurrentCountry() c: CountryContext) {
    return this.cart.getCart(u.userId, c);
  }

  @Post('items')
  add(
    @Body() raw: unknown,
    @CurrentUser() u: AuthContext,
    @CurrentCountry() c: CountryContext,
  ) {
    const body = AddItem.parse(raw);
    return this.cart.addItem(u.userId, c, body);
  }

  @Patch('items/:id')
  patch(
    @Param('id', ParseIntPipe) id: number,
    @Body() raw: unknown,
    @CurrentUser() u: AuthContext,
    @CurrentCountry() c: CountryContext,
  ) {
    const body = UpdateQty.parse(raw);
    return this.cart.updateQuantity(u.userId, c, id, body.quantity);
  }

  @Delete('items/:id')
  remove(
    @Param('id', ParseIntPipe) id: number,
    @CurrentUser() u: AuthContext,
    @CurrentCountry() c: CountryContext,
  ) {
    return this.cart.removeItem(u.userId, c, id);
  }
}
