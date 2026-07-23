// Fixture for permission-chain.
// 3 roles (user, admin, super) but inconsistent checks across 5 routes.

import express from 'express';

const ROLE_USER = 'user';
const ROLE_ADMIN = 'admin';
const ROLE_SUPER = 'super';

const app = express();

// Middleware-mount on /api/admin: requires admin.
app.use('/api/admin', requireAuth(ROLE_ADMIN));

// Route 1: GET (read) - no check needed, OK.
app.get('/users/me', (req, res) => {
    res.json(req.user);
});

// Route 2: POST (mutating) WITH explicit check.
app.post('/users/me/settings', (req, res) => {
    if (req.user.role === ROLE_USER || req.user.role === ROLE_ADMIN) {
        return res.json({ ok: true });
    }
    res.status(403).end();
});

// Route 3: DELETE -- protected by middleware ONLY. No local check.
app.use('/api/admin', express.Router().delete('/purge', (req, res) => {
    res.json({ purged: true });
}));

// Route 4: PUT (mutating) WITH redundant check + divergent role name.
app.put('/orders/:id', (req, res) => {
    if (req.user.role === 'god') {  // typo: should be ROLE_ADMIN
        return res.json({ updated: true });
    }
    res.status(403).end();
});

// Route 5: PATCH (mutating) -- totally unprotected.
app.patch('/account', (req, res) => {
    res.json({ changed: true });
});

// Diamond-divergent set: same role defined differently in 3 places.
const SUPER_DEFINED_HERE = 'god-mode';   // different from ROLE_SUPER
const ADMIN_DEFINED_HERE = 'su';        // different from ROLE_ADMIN
const USER_DEFINED_HERE = 'usr';        // different from ROLE_USER
