import { describe, it, expect, beforeAll, afterAll } from 'jest';
import request from 'supertest';
import { app } from '../../src/app';
import { createDatabase } from '../../src/db';

let db: any;

beforeAll(async () => {
  db = await createDatabase(':memory:');
});

afterAll(async () => {
  await db.close();
});

describe('API Integration', () => {
  it('GET /api/health returns ok', async () => {
    const res = await request(app).get('/api/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
  });

  it('GET /api/users returns user list', async () => {
    const res = await request(app).get('/api/users');
    expect(res.status).toBe(200);
    expect(Array.isArray(res.body)).toBe(true);
  });
});
