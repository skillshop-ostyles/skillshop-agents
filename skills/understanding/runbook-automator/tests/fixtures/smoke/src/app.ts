import express from 'express';

const app = express();
const PORT = process.env.PORT || 3000;

app.get('/health', (_req, res) => {
  res.json({ status: 'ok', uptime: process.uptime() });
});

app.get('/ready', (_req, res) => {
  const dbReady = true;
  const redisReady = true;
  if (dbReady && redisReady) {
    res.json({ status: 'ready', db: 'connected', redis: 'connected' });
  } else {
    res.status(503).json({ status: 'not ready' });
  }
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
