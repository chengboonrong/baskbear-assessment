import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createRemoteJWKSet, jwtVerify, JWTPayload } from 'jose';
import { PrismaService } from '../prisma/prisma.service';
import { AuthContext, RequestWithContext } from '../common/types';

/**
 * Verifies a Cognito-issued JWT and hydrates `req.auth = { userId, cognitoSub }`.
 *
 * Production flow:
 *   1. Read Bearer token from Authorization header.
 *   2. Verify signature against the user pool's JWKS (cached by `jose`).
 *   3. Validate iss + token_use=access (or id) + aud (when access tokens
 *      contain `client_id`) + exp.
 *   4. Look up or create the local user row keyed by `sub`.
 *
 * Dev bypass (DEV_AUTH_BYPASS=true):
 *   - Accepts `Bearer dev:<sub>` and trusts it. Used by tests / curl flows
 *     so reviewers can run the API without AWS. Never enable in prod.
 */
@Injectable()
export class CognitoJwtGuard implements CanActivate {
  private readonly log = new Logger(CognitoJwtGuard.name);
  private jwks?: ReturnType<typeof createRemoteJWKSet>;
  private readonly bypass: boolean;
  private readonly issuer: string;
  private readonly audiences: string[];

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {
    this.bypass = config.get<string>('DEV_AUTH_BYPASS') === 'true';
    const region = config.get<string>('COGNITO_REGION');
    const poolId = config.get<string>('COGNITO_USER_POOL_ID');
    this.issuer = `https://cognito-idp.${region}.amazonaws.com/${poolId}`;
    this.audiences = (config.get<string>('COGNITO_ALLOWED_AUDIENCES') ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean);

    if (!this.bypass && poolId && !poolId.includes('xxxx')) {
      this.jwks = createRemoteJWKSet(
        new URL(`${this.issuer}/.well-known/jwks.json`),
      );
    }
  }

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    const auth = await this.authenticate(req);
    if (!auth) throw new UnauthorizedException('Missing bearer token');
    req.auth = auth;
    return true;
  }

  /**
   * Resolves the caller from the Authorization header, upserting the local
   * user row. Returns `null` when no Bearer token is present; throws (via
   * verifyCognito) when a token is present but invalid. Shared by the strict
   * guard above and the {@link OptionalCognitoJwtGuard} below — the latter is
   * what lets the public voucher list reflect per-user redemption state.
   */
  async authenticate(req: RequestWithContext): Promise<AuthContext | null> {
    const header = req.header('authorization') ?? req.header('Authorization');
    if (!header?.startsWith('Bearer ')) return null;
    const token = header.slice('Bearer '.length).trim();

    let sub: string;
    if (this.bypass && token.startsWith('dev:')) {
      sub =
        token.slice('dev:'.length) ||
        this.config.get<string>('DEV_DEFAULT_SUB') ||
        'demo-user-sub';
    } else if (this.bypass && token === 'dev') {
      sub = this.config.get<string>('DEV_DEFAULT_SUB') || 'demo-user-sub';
    } else {
      sub = await this.verifyCognito(token);
    }

    const user = await this.prisma.user.upsert({
      where: { cognitoSub: sub },
      update: {},
      create: { cognitoSub: sub },
    });
    return { cognitoSub: sub, userId: user.id };
  }

  private async verifyCognito(token: string): Promise<string> {
    if (!this.jwks) {
      throw new UnauthorizedException(
        'Auth not configured (set COGNITO_* or DEV_AUTH_BYPASS=true)',
      );
    }
    try {
      const { payload } = await jwtVerify(token, this.jwks, {
        issuer: this.issuer,
      });
      this.validateClaims(payload);
      if (typeof payload.sub !== 'string') throw new Error('sub missing');
      return payload.sub;
    } catch (e) {
      this.log.warn(`JWT verify failed: ${(e as Error).message}`);
      throw new UnauthorizedException('Invalid token');
    }
  }

  private validateClaims(p: JWTPayload) {
    const tokenUse = (p as { token_use?: string }).token_use;
    if (tokenUse && !['access', 'id'].includes(tokenUse)) {
      throw new Error(`unexpected token_use=${tokenUse}`);
    }
    if (this.audiences.length === 0) return;
    const clientId = (p as { client_id?: string }).client_id;
    const audMatches = Array.isArray(p.aud)
      ? p.aud.some((a) => this.audiences.includes(a))
      : false;
    const auds = typeof p.aud === 'string' ? [p.aud] : (p.aud ?? []);
    if (clientId && this.audiences.includes(clientId)) return;
    if (auds.some((a) => this.audiences.includes(a)) || audMatches) return;
    throw new Error('audience mismatch');
  }
}

/**
 * Best-effort authentication for public endpoints that *enrich* their response
 * when a caller is known (e.g. the voucher list greys out already-redeemed
 * codes). Never blocks the request: a missing or invalid token simply leaves
 * `req.auth` unset, and the handler treats the caller as anonymous.
 */
@Injectable()
export class OptionalCognitoJwtGuard implements CanActivate {
  constructor(private readonly base: CognitoJwtGuard) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<RequestWithContext>();
    try {
      const auth = await this.base.authenticate(req);
      if (auth) req.auth = auth;
    } catch {
      // Present-but-invalid token on a public endpoint → stay anonymous.
      // (The strict guard still 401s on auth'd routes like /validate.)
    }
    return true;
  }
}
