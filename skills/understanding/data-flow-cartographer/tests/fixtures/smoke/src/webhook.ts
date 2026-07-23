// Fixture for data-flow-cartographer.
// Stripe webhook handler: webhook input -> external API verify -> DB.

import express from 'express';
import { prisma } from './db/prisma';
import { logger } from './db/prisma';

const router = express.Router();
const STRIPE_WEBHOOK_SECRET = process.env.STRIPE_WEBHOOK_SECRET || '';

// POST /stripe-webhook — receives raw event body, verifies via Stripe API,
// saves to DB. Flow: raw body -> stripe verification -> prisma.payment.create
router.post('/stripe-webhook', async (req: express.Request, res: express.Response) => {
  const sig = req.headers['stripe-signature'] as string;
  const rawBody = req.body;

  // Simulated Stripe event verification via external API call
  const verified = await fetch('https://api.stripe.com/v1/events/verify', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${process.env.STRIPE_API_KEY}`
    },
    body: JSON.stringify({ signature: sig, payload: rawBody })
  });

  if (!verified.ok) {
    logger.error('Stripe webhook verification failed', { signature: sig });
    return res.status(400).json({ error: 'verification failed' });
  }

  const eventData = await verified.json();
  const { id, type, data } = eventData;

  if (type === 'payment_intent.succeeded') {
    const payment = await prisma.payment.create({
      data: {
        stripeEventId: id,
        amount: data.object.amount,
        currency: data.object.currency,
        status: 'succeeded',
        metadata: JSON.stringify(data.object.metadata || {})
      }
    });
    logger.info('Payment recorded', { id: payment.id, amount: payment.amount });
  }

  return res.status(200).json({ received: true });
});

// Event listener pattern for internal events
const EventEmitter = require('events');
const emitter = new EventEmitter();

emitter.on('payment.failed', async (event: { paymentId: string; reason: string }) => {
  logger.warn('Payment failed', { paymentId: event.paymentId, reason: event.reason });
  await prisma.payment.update({
    where: { id: event.paymentId },
    data: { status: 'failed', metadata: JSON.stringify({ failReason: event.reason }) }
  });
});

export default router;
