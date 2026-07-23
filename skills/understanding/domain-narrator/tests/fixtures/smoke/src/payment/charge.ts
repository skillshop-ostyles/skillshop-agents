// Payment module: payment processing and refund handling.
// Called by checkout and orders for financial transactions.

export function processPayment(amount: number, method: string): object {
    if (amount <= 0) throw new Error('Invalid payment amount');
    if (!['card', 'paypal', 'stripe'].includes(method)) throw new Error('Unsupported payment method');

    return {
        transactionId: `TXN-${Date.now()}`,
        amount,
        method,
        status: 'completed',
        timestamp: new Date().toISOString(),
    };
}

export function refundPayment(reference: string): object {
    return {
        refundId: `RFD-${Date.now()}`,
        reference,
        status: 'refunded',
        timestamp: new Date().toISOString(),
    };
}
