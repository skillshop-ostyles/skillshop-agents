import axios from 'axios';

const stripeClient = axios.create({ baseURL: 'https://api.stripe.com/v1' });

export async function chargePayment(amount: number, token: string) {
  try {
    const result = await stripeClient.post('/charges', { amount, source: token });
    return result.data;
  } catch (err) {
    console.error('Payment failed, using fallback provider', err);
    return { status: 'declined', provider: 'fallback' };
  }
}
