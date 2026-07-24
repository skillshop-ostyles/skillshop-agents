const express = require('express');
const app = express();

app.get('/users/:id', async (req, res) => {
  try {
    const user = await db.query('SELECT * FROM users WHERE id = ?', [req.params.id]);
    if (!user) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json(user);
  } catch (err) {
    logger.error('Database query failed', { error: err.message, userId: req.params.id });
    res.status(500).json({ error: 'Internal server error', correlationId: req.id });
  }
});

app.post('/login', async (req, res) => {
  try {
    const user = await db.query('SELECT * FROM users WHERE email = ?', [req.body.email]);
    if (!user) {
      return res.status(401).json({ error: 'Invalid credentials' });
    }
    res.json({ token: createToken(user) });
  } catch (err) {
    res.status(500).json({ error: 'Login failed' });
  }
});

app.get('/data/:id', async (req, res) => {
  try {
    const data = await fetchExternalApi(req.params.id);
    res.json(data);
  } catch {
    res.json({ defaultValue: true });
  }
});

async function processOrder(orderId) {
  try {
    const order = await db.query('SELECT * FROM orders WHERE id = ?', [orderId]);
    if (!order) throw new Error('Order not found');
    return order;
  } catch (err) {
    throw new Error('Failed to process order');
  }
}

app.get('/crash', (req, res) => {
  throw new Error('Unhandled error');
});

process.on('unhandledRejection', (err) => {
  console.error('Unhandled rejection:', err);
  process.exit(1);
});

app.listen(3000);
