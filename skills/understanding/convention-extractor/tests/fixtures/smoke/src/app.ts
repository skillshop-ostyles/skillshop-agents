import express from 'express';
import { createUser } from './userService';

const app = express();

app.get('/health', async (_req, res) => {
  res.json({ status: 'ok' });
});

app.post('/users', async (req, res) => {
  try {
    const user = await createUser(req.body.name, req.body.email);
    res.status(201).json(user);
  } catch (error: any) {
    res.status(400).json({ error: error.message ?? 'Unknown error' });
  }
});

export default app;
