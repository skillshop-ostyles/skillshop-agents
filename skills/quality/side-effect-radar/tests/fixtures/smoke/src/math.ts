export function add(a: number, b: number): number {
  if (typeof a !== 'number') throw new Error('invalid');
  return a + b;
}
export function multiply(a: number, b: number): number {
  return a * b;
}
