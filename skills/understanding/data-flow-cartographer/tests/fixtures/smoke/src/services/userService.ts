// Fixture for data-flow-cartographer.
// User service called by app.ts POST /users handler.

import { prisma } from '../db/prisma';
import { logger } from '../db/prisma';

export interface User {
  id: string;
  name: string;
  email: string;
  age?: number;
  createdAt: Date;
}

export async function createUser(name: string, email: string, age?: number): Promise<User> {
  // Validation: ensure email format
  if (typeof email !== 'string' || !email.includes('@')) {
    throw new Error('Invalid email address');
  }

  const user = await prisma.user.create({
    data: {
      name,
      email,
      age: age || 0,
      createdAt: new Date()
    }
  });

  return user;
}

export async function getUserByEmail(email: string): Promise<User | null> {
  const user = await prisma.user.findFirst({
    where: { email }
  });

  return user;
}
