// Fixture for session-state-anomaly.
// Scenarios: proper / missing session regeneration after login,
// proper / missing destroy after logout, JWT with/without rotation.

import express from 'express';
import session from 'express-session';

const app = express();

// 1. Proper login with session.regenerate after auth.
app.post('/login/proper', (req, res) => {
    const user = authenticate(req.body.user, req.body.pass);
    if (user) {
        req.session.regenerate((err) => {
            if (err) return res.status(500).json({ error: 'Login failed' });
            req.session.user = user;
            res.json({ ok: true });
        });
    }
});

// 2. Login WITHOUT session.regenerate — session fixation risk.
app.post('/login/fixation', (req, res) => {
    const user = authenticate(req.body.user, req.body.pass);
    if (user) {
        req.session.user = user;                   // BUG: no regenerate call
        res.json({ ok: true });
    }
});

// 3. Proper logout with session.destroy.
app.post('/logout/proper', (req, res) => {
    req.session.destroy((err) => {
        if (err) return res.status(500).json({ error: 'Logout failed' });
        res.clearCookie('connect.sid');
        res.json({ ok: true });
    });
});

// 4. Logout WITHOUT destroy — session lingers.
app.post('/logout/lingering', (req, res) => {
    req.session.user = null;                       // BUG: no destroy, no clearCookie
    res.json({ ok: true });
});

// 5. JWT login with refresh token rotation.
app.post('/token/rotate', (req, res) => {
    const user = authenticate(req.body.user, req.body.pass);
    if (user) {
        const accessToken = jwt.sign({ id: user.id }, SECRET, { expiresIn: '15m' });
        const refreshToken = generateRefreshToken(user);
        setRefreshToken(user.id, refreshToken);    // rotates old token
        rotateRefresh(user.id);
        res.json({ accessToken, refreshToken });
    }
});

// 6. JWT WITHOUT refresh rotation — long-lived token.
app.post('/token/static', (req, res) => {
    const user = authenticate(req.body.user, req.body.pass);
    if (user) {
        const accessToken = jwt.sign({ id: user.id }, SECRET, { expiresIn: '15m' });
        const refreshToken = generateRefreshToken(user);
        // BUG: no rotateRefresh, no setRefreshToken — old token stays valid
        res.json({ accessToken, refreshToken });
    }
});

app.get('/session', (req, res) => {
    const sid = req.sessionID;
    res.json({ sessionId: sid });
});

function authenticate(_u: string, _p: string): any { return { id: 1 }; }
function generateRefreshToken(_u: any): string { return 'rt_' + Math.random(); }
function setRefreshToken(_id: number, _tok: string): void { /* stores in DB */ }
function rotateRefresh(_id: number): void { /* invalidates old, stores new */ }
declare const SECRET: string;
declare const jwt: any;
