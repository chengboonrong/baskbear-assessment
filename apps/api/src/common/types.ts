import { Request } from 'express';

export interface AuthContext {
  /** Cognito `sub` claim. */
  cognitoSub: string;
  /** Internal user.id (resolved by the auth guard). */
  userId: number;
}

export interface CountryContext {
  /** Internal country.id. */
  countryId: number;
  /** ISO-3166-1 alpha-2. */
  countryCode: string;
  /** Resolved locale code (en/ms/th). */
  localeCode: string;
  /** Locale id, for translation table joins. */
  localeId: number;
  /** ISO-4217 (MYR/THB). */
  currencyCode: string;
  taxRateBps: number;
}

export interface RequestWithContext extends Request {
  auth?: AuthContext;
  country?: CountryContext;
}
