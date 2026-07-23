import { describe, it, expect } from 'jest';

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

describe('Validation', () => {
  it('accepts valid email', () => {
    expect(isValidEmail('user@example.com')).toBe(true);
  });

  it('rejects email without domain', () => {
    expect(isValidEmail('user@')).toBe(false);
  });
});
