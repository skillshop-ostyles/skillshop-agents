// Fixture for api-surface-documenter: EventEmitter event handlers.
import { EventEmitter } from 'events';

const orderBus = new EventEmitter();

/**
 * Fired when an order is placed.
 * Payload: { orderId, userId, items }
 */
orderBus.on('order.created', (payload) => {
    console.log('Order created:', payload.orderId);
});

/**
 * Fired when an order is cancelled.
 * Payload: { orderId, reason }
 */
orderBus.on('order.cancelled', (payload) => {
    console.log('Order cancelled:', payload.orderId, payload.reason);
});

export { orderBus };
