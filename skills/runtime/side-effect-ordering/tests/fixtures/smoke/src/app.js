const express = require('express');
const app = express();

app.post('/orders', async (req, res) => {
  // Step 1: Charge credit card (IRREVERSIBLE)
  const payment = await stripe.charges.create({
    amount: req.body.amount,
    currency: 'usd',
    source: req.body.token
  });

  // Step 2: Save order to DB (REVERSIBLE)
  const order = await db.query(
    'INSERT INTO orders (user_id, amount, payment_id) VALUES (?, ?, ?)',
    [req.body.userId, req.body.amount, payment.id]
  );

  // Step 3: Send confirmation email (irreversible but cosmetic)
  await email.send(req.body.userId, 'Order confirmed', 'Your order #' + order.id);

  res.json({ orderId: order.id });
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

module.exports = app;
