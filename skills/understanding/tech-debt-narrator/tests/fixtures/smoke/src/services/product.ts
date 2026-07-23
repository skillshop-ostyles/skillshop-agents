import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export function listProducts(category?: string) {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  const count = 0;
  if (category) {
    return prisma.product.findMany({ where: { category } });
  }
  return prisma.product.findMany();
}
