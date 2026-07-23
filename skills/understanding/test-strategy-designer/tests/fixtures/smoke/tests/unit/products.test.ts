import { describe, it, expect } from 'jest';

interface Product { id: string; name: string; price: number }
const products: Product[] = [];

function addProduct(name: string, price: number): Product {
  const p: Product = { id: `prod_${Date.now()}`, name, price };
  products.push(p);
  return p;
}

describe('Products', () => {
  it('adds a product with correct fields', () => {
    const p = addProduct('Widget', 9.99);
    expect(p.name).toBe('Widget');
    expect(p.price).toBe(9.99);
  });
});
