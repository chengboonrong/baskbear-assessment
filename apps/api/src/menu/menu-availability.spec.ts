import { resolveItemAvailability } from './menu-availability';

describe('resolveItemAvailability', () => {
  it('is available when country-available and no outlet override', () => {
    expect(resolveItemAvailability(true)).toBe(true);
    expect(resolveItemAvailability(true, undefined)).toBe(true);
  });

  it('is unavailable when the country price is unavailable, override aside', () => {
    expect(resolveItemAvailability(false)).toBe(false);
    expect(resolveItemAvailability(false, { isAvailable: true })).toBe(false);
  });

  it('outlet override can only restrict an otherwise-available item', () => {
    expect(resolveItemAvailability(true, { isAvailable: false })).toBe(false);
    expect(resolveItemAvailability(true, { isAvailable: true })).toBe(true);
  });
});
