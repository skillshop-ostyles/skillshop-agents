export function formatCurrency(value: number): string {
  // HACK: this works but should be refactored to use Intl.NumberFormat
  return `$${value.toFixed(2)}`;
}

export function formatDate(date: Date): string {
  return date.toISOString().split('T')[0];
}
