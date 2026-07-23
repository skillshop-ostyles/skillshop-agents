import { describe, it, expect } from 'jest';

interface OrderItem { productId: string; quantity: number; price: number }

function calcTotal(items: OrderItem[]): number {
  return items.reduce((sum, i) => sum + i.price * i.quantity, 0);
}

describe('Order helpers', () => {
  it('calculates total from items', () => {
    const items: OrderItem[] = [
      { productId: 'p1', quantity: 2, price: 10 },
      { productId: 'p2', quantity: 1, price: 5 },
    ];
    expect(calcTotal(items)).toBe(25);
  });

  it('returns 0 for empty items', () => {
    expect(calcTotal([])).toBe(0);
  });
});
