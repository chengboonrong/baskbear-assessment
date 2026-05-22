import { Module } from '@nestjs/common';
import { CognitoJwtGuard, OptionalCognitoJwtGuard } from './cognito-jwt.guard';
import { AuthController } from './auth.controller';

@Module({
  providers: [CognitoJwtGuard, OptionalCognitoJwtGuard],
  exports: [CognitoJwtGuard, OptionalCognitoJwtGuard],
  controllers: [AuthController],
})
export class AuthModule {}
