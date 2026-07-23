// Fixture for rate-limit-shape-analyzer.
// 5 endpoints: 3 post/put/delete limited, 2 without.

import express from 'express';
import { rateLimit } from 'express-rate-limit';
import { limiter } from './limits';

const app = express();

// 1. Limited POST.
app.post('/api/users', rateLimit({ windowMs: 60000, max: 5 }), (req, res) => { res.json({ created: true }); });

// 2. Limited POST with per-tier.
app.post('/api/users/login', limiter({ points: 3, duration: 60 }), (req, res) => {});

// 3. Limited PUT.
app.put('/api/users/:id', limiter({ points: 30, duration: 60 }), (req, res) => {});

// 4. UNLIMITED DELETE -- export all users, expensive:
app.delete('/api/users/all', (req, res) => { res.json({ deleted: 999999 }); });

// 5. UNLIMITED PATCH -- bulk-update.
app.patch('/api/users/bulk', (req, res) => { res.json({ updated: true }); });

// 6. Cheap GET (no limit needed).
app.get('/api/users/me', (req, res) => { res.json({ me: true }); });
