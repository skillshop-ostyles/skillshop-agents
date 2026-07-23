import { describe, it, expect } from 'jest';
import request from 'supertest';
import { app } from '../../src/app';

describe('Payment API', () => {
  it('processes payment with valid token', async () => {
    const res = await request(app)
      .post('/api/payments')
      .send({ amount: 50, token: 'tok_visa' });
    expect(res.status).toBe(200);
    expect(res.body.success).toBe(true);
    expect(res.body.transactionId).toBeDefined();
  });

  it('rejects payment with invalid amount', async () => {
    const res = await request(app)
      .post('/api/payments')
      .send({ amount: -1, token: 'tok_visa' });
    expect(res.status).toBe(400);
    expect(res.body.success).toBe(false);
  });
});
