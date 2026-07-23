// Fixture for data-flow-cartographer.
// Express app with POST /users: user input -> DB + log.

import express from 'express';
import { createUser } from './services/userService';
import { prisma } from './db/prisma';
import { logger } from './db/prisma';

const app = express();
app.use(express.json());

// POST /users — receives user data, creates in DB, logs result.
// Flow: req.body -> createUser -> prisma.user.create -> logger.info
app.post('/users', async (req: express.Request, res: express.Response) => {
  const { name, email, age } = req.body;

  if (typeof name !== 'string' || typeof email !== 'string') {
    return res.status(400).json({ error: 'name and email required' });
  }

  const user = await createUser(name, email, age);
  logger.info('User created', { id: user.id, email: user.email });
  return res.status(201).json(user);
});

// GET /users — reads all users from DB.
// Flow: prisma.user.findMany -> res.json
app.get('/users', async (_req: express.Request, res: express.Response) => {
  const users = await prisma.user.findMany();
  return res.json(users);
});

export default app;
