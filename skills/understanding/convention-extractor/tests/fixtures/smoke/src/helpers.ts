export const formatCurrency = (amount: number, currency: string = 'USD'): string => {
  return new Intl.NumberFormat('en-US', { style: 'currency', currency }).format(amount);
};

export const sleep = (ms: number): Promise<void> => {
  return new Promise((resolve) => setTimeout(resolve, ms));
};

export const groupBy = <T>(items: T[], key: keyof T): Map<string, T[]> => {
  return items.reduce((map, item) => {
    const k = String(item[key]);
    const group = map.get(k) ?? [];
    group.push(item);
    map.set(k, group);
    return map;
  }, new Map());
};
