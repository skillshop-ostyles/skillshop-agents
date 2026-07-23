export interface SalesReport {
  period: string;
  totalRevenue: number;
  orderCount: number;
}

export function generateReport(start: Date, end: Date): SalesReport {
  return {
    period: `${start.toISOString()}_${end.toISOString()}`,
    totalRevenue: 0,
    orderCount: 0,
  };
}
