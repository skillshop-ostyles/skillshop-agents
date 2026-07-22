class Order {
  id: string;
}

function placeOrder(item: string): Order {
  return { id: item } as Order;
}
