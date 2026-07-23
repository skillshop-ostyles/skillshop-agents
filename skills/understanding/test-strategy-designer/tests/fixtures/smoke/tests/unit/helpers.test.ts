import { describe, it, expect } from 'jest';

function formatCurrency(amount: number): string {
  return `$${amount.toFixed(2)}`;
}

function truncate(str: string, max: number): string {
  return str.length <= max ? str : str.slice(0, max) + '...';
}

describe('Helpers', () => {
  it('formats currency', () => {
    expect(formatCurrency(10.5)).toBe('$10.50');
  });

  it('truncates long strings', () => {
    expect(truncate('hello world', 5)).toBe('hello...');
  });
});
