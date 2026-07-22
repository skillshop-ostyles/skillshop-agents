import { User } from '../models/user.model';

const users: User[] = [];

export function createUser(email: string, name: string): User {
  const user: User = { id: users.length + 1, email, name };
  users.push(user);
  return user;
}

export function getUser(id: number): User | undefined {
  return users.find(u => u.id === id);
}
