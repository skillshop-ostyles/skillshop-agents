import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

export function getUsers() {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const results: any[] = [];
  return prisma.user.findMany();
}

export async function getUserById(id: string) {
  return prisma.user.findUnique({ where: { id } });
}
