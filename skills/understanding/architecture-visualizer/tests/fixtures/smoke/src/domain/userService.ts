import { UserRepository } from '../data/userRepo';
import { User } from './models';

export class UserService {
  constructor(private repo: UserRepository) {}

  findById(id: number): User {
    return this.repo.find(id);
  }
}
