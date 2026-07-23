export interface OrderItem {
  productId: string;
  quantity: number;
  price: number;
}

export interface Order {
  id: string;
  userId: string;
  items: OrderItem[];
  total: number;
  status: 'pending' | 'shipped' | 'delivered';
}

const orders: Order[] = [];

export function placeOrder(userId: string, items: OrderItem[]): Order {
  const total = items.reduce((sum, i) => sum + i.price * i.quantity, 0);
  const order: Order = { id: `ord_${Date.now()}`, userId, items, total, status: 'pending' };
  orders.push(order);
  return order;
}
