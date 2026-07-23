import { describe, it, expect } from 'jest';
import { createUser, findUser } from '../../src/users/users';

describe('Users', () => {
  it('creates a user with default role', () => {
    const user = createUser('test@test.com');
    expect(user.email).toBe('test@test.com');
    expect(user.role).toBe('user');
  });

  it('finds user by email', () => {
    const user = findUser('test@test.com');
    expect(user).toBeDefined();
  });

  it('returns undefined for unknown email', () => {
    expect(findUser('nobody@test.com')).toBeUndefined();
  });
});
