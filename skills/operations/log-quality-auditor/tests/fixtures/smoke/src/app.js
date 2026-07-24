const express = require('express');
const app = express();

app.get('/users/:id', async (req, res) => {
  const userId = req.params.id;
  logger.info('Fetching user', { userId, correlationId: req.correlationId });

  try {
    const user = await db.users.findOne({ id: userId });
    logger.info('User fetched successfully', { userId });
    res.json(user);
  } catch (err) {
    logger.error('Failed to fetch user: ' + err.message);
    res.status(500).send('Error');
  }
});

app.post('/login', async (req, res) => {
  const { email, password } = req.body;
  console.log('Login attempt: ' + email);

  try {
    const user = await db.users.findOne({ email });
    if (!user) {
      logger.warn('Login failed: user not found');
      return res.status(401).send('Invalid credentials');
    }
    logger.info('User logged in', { userId: user.id });
    res.json({ token: createToken(user) });
  } catch (err) {
    console.error(err);
    res.status(500).send('Error');
  }
});

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

function processPayment(orderId, creditCard) {
  logger.info('Processing payment', { orderId });
  try {
    const result = paymentGateway.charge(creditCard.number, creditCard.amount);
    logger.info('Payment processed', { orderId, result: result.id });
    return result;
  } catch (err) {
    logger.error(err);
    throw err;
  }
}

app.listen(3000);
