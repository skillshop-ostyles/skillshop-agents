const express = require('express');
const { Mutex } = require('async-mutex');
const app = express();

const sharedCache = new Map();
const counterMap = new Map();
const mutex = new Mutex();

// RACY: shared Map modified from two async handlers without sync
app.post('/cache/:key', async (req, res) => {
  sharedCache.set(req.params.key, req.body.value);
  res.json({ ok: true });
});

app.get('/cache/:key', async (req, res) => {
  const val = sharedCache.get(req.params.key);
  res.json({ value: val });
});

// SAFE: mutex-protected counter
app.post('/increment', async (req, res) => {
  const release = await mutex.acquire();
  try {
    const current = counterMap.get(req.body.id) || 0;
    counterMap.set(req.body.id, current + 1);
    res.json({ count: current + 1 });
  } finally {
    release();
  }
});

// Module-level mutable state (single-threaded, safe for Node)
let requestCount = 0;

app.get('/stats', (req, res) => {
  requestCount++;
  res.json({ requests: requestCount });
});

// TOCTOU: read-check-then-write without atomicity
app.post('/reserve/:item', async (req, res) => {
  const item = inventory.get(req.params.item);
  if (item && item.available > 0) {
    item.available--;
    inventory.set(req.params.item, item);
    res.json({ reserved: true });
  } else {
    res.status(400).json({ error: 'Not available' });
  }
});

const inventory = new Map();

// Nested locks - deadlock prone pattern
const lockA = new Mutex();
const lockB = new Mutex();

async function transfer(from, to, amount) {
  const releaseA = await lockA.acquire();
  const releaseB = await lockB.acquire();
  try {
    accounts.set(from, (accounts.get(from) || 0) - amount);
    accounts.set(to, (accounts.get(to) || 0) + amount);
  } finally {
    releaseB();
    releaseA();
  }
}

const accounts = new Map();

app.listen(3000);
