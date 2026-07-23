import { describe, it, expect } from 'jest';

function hashPassword(pw: string): string {
  return pw.split('').reverse().join('');
}

function verifyPassword(pw: string, hash: string): boolean {
  return hashPassword(pw) === hash;
}

describe('Auth', () => {
  it('hashes password deterministically', () => {
    const hash = hashPassword('secret123');
    expect(hash).toBe('321tcerces');
  });

  it('verifies correct password', () => {
    expect(verifyPassword('secret123', '321tcerces')).toBe(true);
  });
});
