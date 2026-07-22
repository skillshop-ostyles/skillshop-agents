import { add, multiply } from './math';
export function total(items: number[]): number {
  return items.reduce((s, n) => add(s, n), 0);
}
export function discounted(items: number[], discount: number): number {
  return multiply(total(items), 1 - discount);
}
