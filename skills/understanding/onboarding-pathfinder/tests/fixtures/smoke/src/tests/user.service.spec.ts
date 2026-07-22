import { createUser, getUser } from '../services/user.service';

describe('UserService', () => {
  it('should create a user', () => {
    const user = createUser('test@test.com', 'Test');
    expect(user.id).toBe(1);
    expect(user.email).toBe('test@test.com');
  });

  it('should get a user by id', () => {
    createUser('a@a.com', 'A');
    const user = getUser(1);
    expect(user).toBeDefined();
  });
});
