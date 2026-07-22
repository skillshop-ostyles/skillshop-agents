export function calculateTotal(items: number[], taxRate: number): number {
  if (items.length === 0) {
    throw new Error('items must not be empty');
  }
  const subtotal = items.reduce((sum, i) => sum + i, 0);
  if (taxRate < 0 || taxRate > 1) {
    throw new Error('taxRate must be between 0 and 1');
  }
  return subtotal * (1 + taxRate);
}
