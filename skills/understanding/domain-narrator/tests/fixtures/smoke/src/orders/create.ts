// Orders module: order creation and lifecycle management.
// Validates payment and triggers payment processing.

import { checkPayment, placeOrder } from '../checkout/process';
import { processPayment, refundPayment } from '../payment/charge';
import { getCart } from '../cart/manage';

export function createOrder(userId: string): object {
    const cart = getCart(userId);
    if (!cart || (cart as any).items.length === 0) {
        throw new Error('Cart is empty');
    }
    const total = (cart as any).items.reduce((sum: number, item: any) => sum + item.price * item.qty, 0);
    checkPayment(total);
    const payment = processPayment(total, 'card');
    return placeOrder(userId, (cart as any).items, payment);
}

export function cancelOrder(orderId: string): boolean {
    refundPayment(orderId);
    return true;
}
