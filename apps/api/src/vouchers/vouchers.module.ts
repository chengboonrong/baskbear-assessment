import { Module } from '@nestjs/common';
import { VouchersController } from './vouchers.controller';
import { VoucherService } from './voucher.service';
import { CartModule } from '../cart/cart.module';

@Module({
  imports: [CartModule],
  controllers: [VouchersController],
  providers: [VoucherService],
  exports: [VoucherService],
})
export class VouchersModule {}
