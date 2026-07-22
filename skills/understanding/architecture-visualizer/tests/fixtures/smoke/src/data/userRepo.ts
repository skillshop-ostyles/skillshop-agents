import { User } from '../domain/models';

export class UserRepository {
  private users: User[] = [];

  find(id: number): User {
    return this.users.find(u => u.id === id);
  }

  save(user: User): void {
    this.users.push(user);
  }
}
