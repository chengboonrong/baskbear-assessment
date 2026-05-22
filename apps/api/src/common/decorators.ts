import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { AuthContext, CountryContext, RequestWithContext } from './types';

export const CurrentUser = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthContext => {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    if (!req.auth)
      throw new Error('AuthContext missing — is AuthGuard applied?');
    return req.auth;
  },
);

/** Like {@link CurrentUser} but returns `null` instead of throwing when no
 *  auth context is present — for optional-auth endpoints (e.g. the public
 *  voucher list, which enriches its response only when the caller is known). */
export const CurrentUserOptional = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): AuthContext | null => {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    return req.auth ?? null;
  },
);

export const CurrentCountry = createParamDecorator(
  (_: unknown, ctx: ExecutionContext): CountryContext => {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    if (!req.country) {
      throw new Error(
        'CountryContext missing — is CountryInterceptor applied?',
      );
    }
    return req.country;
  },
);
