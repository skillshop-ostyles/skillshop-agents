// Fixture for authz-coverage-gap-detector.
// Mounts admin to /api/admin via middleware. Nested delete inherits only.
// One patch has explicit check. One patch has no check + no mount.

import express from 'express';

const app = express();

// Mount admin role middleware on /api/admin.
app.use('/api/admin', requireAuth('admin'));

// 1. Mounted POST (inherits admin) + local-check redundant.
app.post('/api/admin/users', requireRole('admin'), (req, res) => {
    res.json({ created: true });
});

// 2. Nested DELETE under mounted path - inherits admin ONLY, no local check.
const adminRouter = express.Router();
adminRouter.delete('/api/admin/purge', (req, res) => {
    res.json({ purged: true });
});
app.use('/api/admin', adminRouter);

// 3. Patch OUTSIDE /api/admin mount, no local check.
app.patch('/api/users/bulk', (req, res) => {
    res.json({ updated: true });
});

// 4. Patch OUTSIDE mount, WITH local explicit check.
app.delete('/api/orders/:id', (req, res) => {
    if (req.user.role === 'admin') {
        return res.json({ deleted: true });
    }
    res.status(403).end();
});
