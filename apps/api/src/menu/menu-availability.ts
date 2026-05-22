/**
 * Resolves whether a menu item is orderable, combining its per-country
 * availability flag with an optional per-outlet override.
 *
 * An outlet override can only *further restrict*: a country-unavailable item is
 * never re-enabled by an outlet. The absence of an override row means the item
 * is available at that outlet (overrides store exceptions only).
 */
export function resolveItemAvailability(
  countryAvailable: boolean,
  outletOverride?: { isAvailable: boolean },
): boolean {
  return countryAvailable && (outletOverride?.isAvailable ?? true);
}
