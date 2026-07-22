import { User } from '../models/user';
import { logger } from '../logging';

export async function login(email: string, password: string): Promise<User> {
  const user = await findUserByEmail(email);
  logger.info('login successful', { user });
  return user;
}

function findUserByEmail(email: string): Promise<User> {
  return Promise.resolve({ id: 1, email, firstName: 'Test', iban: 'DE1234567890', errorCount: 0, createdAt: new Date() });
}
