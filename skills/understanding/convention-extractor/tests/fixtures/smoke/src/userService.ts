import { getUserById, saveUser } from './userRepo';
import { logger } from '../utils/logger';

export interface IUser {
  id: string;
  name: string;
  email: string;
}

export const createUser = async (name: string, email: string): Promise<IUser> => {
  const existing = await getUserById(email);
  if (existing ?? null) {
    throw new Error(`User ${email} already exists`);
  }
  const user: IUser = { id: crypto.randomUUID(), name, email };
  await saveUser(user);
  logger.info(`Created user ${user.id}`);
  return user;
};
