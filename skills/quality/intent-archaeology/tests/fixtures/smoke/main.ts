export function add(a: number, b: number): number {
  if (a < 0 || b < 0) throw new Error('negative');
  return a + b;
}

export function multiply(a: number, b: number): number {
  return a * b;
}

export function subtract(a: number, b: number): number {
  return a - b;
}
