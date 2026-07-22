import express from 'express';
import { authMiddleware } from './auth';
import { requireAdmin } from './guards';

const app = express();

// Global mount with auth protection
app.use('/api', authMiddleware);

// Protected route with role guard
app.get('/api/orders', requireAdmin, (req, res) => {
  res.json({ orders: [] });
});

// Explicitly public route
app.get('/health', (req, res) => {
  res.json({ status: 'ok' });
});

export default app;
