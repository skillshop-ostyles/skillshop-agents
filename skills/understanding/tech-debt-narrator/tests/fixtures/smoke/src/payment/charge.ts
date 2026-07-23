import { Stripe } from 'stripe';

const stripe = new Stripe('sk_test_placeholder', { apiVersion: '2023-10-16' });

export async function chargeCustomer(amount: number, paymentMethodId: string) {
  // @ts-ignore - Stripe type definitions are out of sync with API version
  const payment = await stripe.paymentIntents.create({
    amount,
    currency: 'usd',
    payment_method: paymentMethodId,
    confirm: true,
  });

  return { id: payment.id, status: payment.status };
}
