import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthContext, CountryContext, RequestWithContext } from './types';

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthContext => {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    if (!req.auth) throw new Error('AuthContext missing — is AuthGuard applied?');
    return req.auth;
  },
);

export const CurrentCountry = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): CountryContext => {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    if (!req.country) {
      throw new Error('CountryContext missing — is CountryInterceptor applied?');
    }
    return req.country;
  },
);
