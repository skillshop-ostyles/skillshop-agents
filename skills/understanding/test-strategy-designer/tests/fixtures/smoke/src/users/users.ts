export interface User {
  id: string;
  email: string;
  role: 'admin' | 'user';
}

const users: User[] = [];

export function createUser(email: string, role: User['role'] = 'user'): User {
  const user: User = { id: `usr_${Date.now()}`, email, role };
  users.push(user);
  return user;
}

export function findUser(email: string): User | undefined {
  return users.find(u => u.email === email);
}
