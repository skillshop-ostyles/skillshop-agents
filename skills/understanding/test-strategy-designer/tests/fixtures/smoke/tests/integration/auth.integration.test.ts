import { describe, it, expect } from 'jest';
import request from 'supertest';
import { app } from '../../src/app';

describe('Auth API', () => {
  it('POST /api/auth/login returns token', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'admin@test.com', password: 'admin123' });
    expect(res.status).toBe(200);
    expect(res.body.token).toBeDefined();
  });

  it('POST /api/auth/login rejects bad credentials', async () => {
    const res = await request(app)
      .post('/api/auth/login')
      .send({ email: 'bad@test.com', password: 'wrong' });
    expect(res.status).toBe(401);
  });
});
