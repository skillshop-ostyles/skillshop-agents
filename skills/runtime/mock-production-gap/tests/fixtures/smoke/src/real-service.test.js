const { getUser } = require('./real-service');

jest.mock('./real-service', () => ({
  getUser: jest.fn().mockReturnValue({
    id: 1
    // Missing: email, status, createdAt - test passes but code using these fields crashes
  })
}));

test('getUser returns user', () => {
  const user = getUser(1);
  expect(user.id).toBe(1);
  // Test passes but user.email crashes in production
});
