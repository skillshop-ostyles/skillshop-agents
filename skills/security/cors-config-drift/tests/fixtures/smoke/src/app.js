// Fixture for cors-config-drift.
// CORS scenarios: safe-specific, fatal wildcard+credentials, header-based,
// route-specific divergence, preflight handler.

const express = require('express');
const cors = require('cors');

const app = express();

// 1. Safe: cors() with specific origin + credentials: true (non-wildcard, acceptable).
const safeCorsOptions = {
    origin: 'https://trusted-frontend.example.com',
    credentials: true,
    methods: ['GET', 'POST'],
    allowedHeaders: ['Content-Type', 'Authorization'],
};
app.use('/api/trusted', cors(safeCorsOptions));

// 2. Dangerous: cors({origin:'*', credentials:true}) — fatally insecure.
// Browser sends cookies cross-origin to any domain.
const dangerousCorsOptions = {
    origin: '*',
    credentials: true,
    methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'],
    allowedHeaders: '*',
};
app.use('/api/public', cors(dangerousCorsOptions));

// 3. Header-based: raw res.header sets Access-Control-Allow-Origin to '*'
// with allow-credentials header — bypasses centralized cors() policy.
app.get('/api/legacy/data', (req, res) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Credentials', 'true');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.json({ data: 'legacy' });
});

// 4. Route-specific divergence: one route permissive, another restrictive.
app.get('/api/v1/users', cors({ origin: '*', credentials: true }), (req, res) => {
    res.json({ users: [] });
});

app.get('/api/v1/users/me', cors({ origin: 'https://app.example.com' }), (req, res) => {
    res.json({ user: 'me' });
});

// 5. Preflight: app.options handler with custom config.
app.options('/api/upload', cors({
    origin: 'https://uploader.example.com',
    methods: ['POST', 'PUT'],
    allowedHeaders: ['Content-Type', 'X-Custom'],
    maxAge: 86400,
}));

app.post('/api/upload', (req, res) => {
    res.json({ uploaded: true });
});
