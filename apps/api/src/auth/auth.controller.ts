import { Controller, Get, UseGuards } from '@nestjs/common';
import { CognitoJwtGuard } from './cognito-jwt.guard';
import { CurrentUser } from '../common/decorators';
import type { AuthContext } from '../common/types';
import { PrismaService } from '../prisma/prisma.service';

@Controller('v1/auth')
export class AuthController {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Exchange a Cognito-issued token for an app session.
   * Idempotent — first call creates the user row, later calls return it.
   */
  @UseGuards(CognitoJwtGuard)
  @Get('exchange')
  async exchange(@CurrentUser() auth: AuthContext) {
    const user = await this.prisma.user.findUnique({
      where: { id: auth.userId },
      select: {
        id: true, email: true, phone: true,
        defaultCountry: { select: { code: true } },
        defaultLocale:  { select: { code: true } },
      },
    });
    return { user };
  }
}
