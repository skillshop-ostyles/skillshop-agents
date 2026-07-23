// Fixture for data-flow-cartographer.
// Prisma client setup with CRUD operations.

import { PrismaClient } from '@prisma/client';

export const prisma = new PrismaClient();

// Logger stub matching common logger interface
export const logger = {
  info: (msg: string, meta?: any) => console.log(`[INFO] ${msg}`, meta || ''),
  warn: (msg: string, meta?: any) => console.warn(`[WARN] ${msg}`, meta || ''),
  error: (msg: string, meta?: any) => console.error(`[ERROR] ${msg}`, meta || ''),
  debug: (msg: string, meta?: any) => console.debug(`[DEBUG] ${msg}`, meta || '')
};

// Seed function to demonstrate findMany sink
export async function getAllUsers() {
  return await prisma.user.findMany();
}

export async function getPaymentById(id: string) {
  return await prisma.payment.findUnique({ where: { id } });
}
