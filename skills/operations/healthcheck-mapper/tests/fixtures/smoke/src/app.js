const express = require('express');
const app = express();

app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

app.get('/healthz', async (req, res) => {
  try {
    await db.ping();
    await redis.ping();
    res.json({ status: 'healthy', db: 'ok', cache: 'ok' });
  } catch (err) {
    res.status(503).json({ status: 'unhealthy', error: err.message });
  }
});

app.get('/ready', async (req, res) => {
  try {
    await db.ping();
    res.json({ status: 'ready' });
  } catch {
    res.status(503).json({ status: 'not ready' });
  }
});

const server = app.listen(3000, () => {
  console.log('Server running on port 3000');
});
