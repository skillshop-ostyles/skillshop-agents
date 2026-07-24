const express = require('express');
const Redis = require('ioredis');
const app = express();

const redis = new Redis();

// GOOD: Redis cache with TTL + explicit invalidation
app.get('/session/:token', async (req, res) => {
  const cached = await redis.get('session:' + req.params.token);
  if (cached) return res.json(JSON.parse(cached));
  const session = await db.query('SELECT * FROM sessions WHERE token = ?', [req.params.token]);
  await redis.setex('session:' + req.params.token, 3600, JSON.stringify(session));
  res.json(session);
});

app.post('/logout', async (req, res) => {
  await redis.del('session:' + req.body.token);
  res.json({ ok: true });
});

// BAD: In-memory Map cache without invalidation
const profileCache = new Map();

app.get('/profile/:id', async (req, res) => {
  if (profileCache.has(req.params.id)) {
    return res.json(profileCache.get(req.params.id));
  }
  const profile = await db.query('SELECT * FROM profiles WHERE id = ?', [req.params.id]);
  profileCache.set(req.params.id, profile);
  setTimeout(() => profileCache.delete(req.params.id), 300000);
  res.json(profile);
});

// GOOD: Memoized expensive computation
function fibonacci(n) {
  const memo = new Map();
  function fib(x) {
    if (memo.has(x)) return memo.get(x);
    if (x <= 1) return x;
    const result = fib(x - 1) + fib(x - 2);
    memo.set(x, result);
    return result;
  }
  return fib(n);
}

// MISSED: Frequently accessed catalog, never cached
app.get('/catalog', async (req, res) => {
  const items = await db.query('SELECT * FROM products');
  res.json(items);
});

// HTTP caching headers
app.get('/static/:file', (req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=31536000');
  res.sendFile(req.params.file, { root: './public' });
});

app.listen(3000);
