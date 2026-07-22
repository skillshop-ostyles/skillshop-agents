import { describe, it, expect } from 'vitest';
import { calculateTotal } from '../src/invoice';

describe('calculateTotal', () => {
  it('calculates total with tax for normal items', () => {
    expect(calculateTotal([10, 20], 0.1)).toBe(33);
  });
});
