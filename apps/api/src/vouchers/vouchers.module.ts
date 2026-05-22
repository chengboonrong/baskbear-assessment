import { Module } from '@nestjs/common';
import { VouchersController } from './vouchers.controller';
import { VoucherService } from './voucher.service';
import { CartModule } from '../cart/cart.module';
import { AuthModule } from '../auth/auth.module';

@Module({
  imports: [CartModule, AuthModule],
  controllers: [VouchersController],
  providers: [VoucherService],
  exports: [VoucherService],
})
export class VouchersModule {}
