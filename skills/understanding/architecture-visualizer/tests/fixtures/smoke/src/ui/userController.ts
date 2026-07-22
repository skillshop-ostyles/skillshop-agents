import { UserService } from '../domain/userService';
import { User } from '../domain/models';

export class UserController {
  constructor(private service: UserService) {}

  getUser(id: number): User {
    return this.service.findById(id);
  }
}
