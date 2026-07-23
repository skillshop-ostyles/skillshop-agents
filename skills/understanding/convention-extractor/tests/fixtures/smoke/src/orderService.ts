import { findOrdersByUser, insertOrder } from './orderRepo';

export interface IOrder {
  orderId: string;
  userId: string;
  total: number;
  status: string;
}

export const getOrdersForUser = async (userId: string): Promise<IOrder[]> => {
  const orders = await findOrdersByUser(userId);
  return orders ?? [];
};

export const placeOrder = async (userId: string, items: unknown[]): Promise<IOrder> => {
  const total = calculateTotal(items);
  const order: IOrder = { orderId: crypto.randomUUID(), userId, total, status: 'pending' };
  await insertOrder(order);
  return order;
};

function calculateTotal(items: unknown[]): number {
  return items.reduce((sum, item: any) => sum + (item.price ?? 0), 0);
}
