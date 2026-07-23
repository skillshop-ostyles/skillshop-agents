// Cart module: shopping cart management.
// Supports add, remove, and query operations for user carts.

import { getProducts } from '../products/list';

const carts: Record<string, any> = {};

export function addToCart(userId: string, productId: number, qty: number): object {
    const products = getProducts();
    const product = products.find((p: any) => p.id === productId);
    if (!product) throw new Error('Product not found');

    if (!carts[userId]) carts[userId] = { userId, items: [] };
    const existing = carts[userId].items.find((i: any) => i.productId === productId);
    if (existing) {
        existing.qty += qty;
    } else {
        carts[userId].items.push({ productId, name: (product as any).name, price: (product as any).price, qty });
    }
    return carts[userId];
}

export function removeFromCart(userId: string, productId: number): object {
    if (!carts[userId]) return carts[userId] || { userId, items: [] };
    carts[userId].items = carts[userId].items.filter((i: any) => i.productId !== productId);
    return carts[userId];
}

export function getCart(userId: string): object | null {
    return carts[userId] || null;
}
