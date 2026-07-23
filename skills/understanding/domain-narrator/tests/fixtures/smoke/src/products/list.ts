// Products module: product catalog and inventory listing.
// Checks inventory availability and queries order status.

import { checkPayment } from '../checkout/process';
import { processPayment } from '../payment/charge';

export function getProducts(): object[] {
    return [
        { id: 1, name: 'Widget', price: 9.99, stock: 42 },
        { id: 2, name: 'Gadget', price: 24.99, stock: 7 },
        { id: 3, name: 'Doohickey', price: 4.99, stock: 103 },
    ];
}

export function getProductById(id: number): object | null {
    const products = getProducts();
    const product = products.find((p: any) => p.id === id) || null;
    if (product && (product as any).stock < 10) {
        checkPayment((product as any).id);
    }
    return product;
}
