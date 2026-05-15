import { BadRequestException, Body, Controller, Get, Headers, Param, ParseIntPipe, Post, UseGuards, UseInterceptors } from '@nestjs/common';
import { FulfilmentType } from '@prisma/client';
import { z } from 'zod';
import { CognitoJwtGuard } from '../auth/cognito-jwt.guard';
import { CountryInterceptor } from '../countries/country.interceptor';
import { CurrentCountry, CurrentUser } from '../common/decorators';
import type { AuthContext, CountryContext } from '../common/types';
import { OrdersService } from './orders.service';

const PlaceOrder = z.object({
  fulfilmentType: z.nativeEnum(FulfilmentType),
  outletId: z.number().int().positive().optional(),
  voucherCode: z.string().min(1).max(32).optional(),
  notes: z.string().max(512).optional(),
});

@Controller('v1/orders')
@UseGuards(CognitoJwtGuard)
@UseInterceptors(CountryInterceptor)
export class OrdersController {
  constructor(private readonly orders: OrdersService) {}

  @Get()
  list(@CurrentUser() u: AuthContext) {
    return this.orders.list(u.userId);
  }

  @Get(':id')
  one(@Param('id', ParseIntPipe) id: number, @CurrentUser() u: AuthContext) {
    return this.orders.findOne(u.userId, id);
  }

  @Post()
  place(
    @Body() raw: unknown,
    @CurrentUser() u: AuthContext,
    @CurrentCountry() c: CountryContext,
    @Headers('idempotency-key') key?: string,
  ) {
    if (!key) throw new BadRequestException('IDEMPOTENCY_KEY_REQUIRED');
    const body = PlaceOrder.parse(raw);
    return this.orders.place(u.userId, c, { ...body, idempotencyKey: key });
  }
}
