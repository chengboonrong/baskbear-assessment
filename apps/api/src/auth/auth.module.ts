import { Module } from '@nestjs/common';
import { CognitoJwtGuard } from './cognito-jwt.guard';
import { AuthController } from './auth.controller';

@Module({
  providers: [CognitoJwtGuard],
  exports: [CognitoJwtGuard],
  controllers: [AuthController],
})
export class AuthModule {}
