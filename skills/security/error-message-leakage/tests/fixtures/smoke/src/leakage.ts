// Fixture for error-message-leakage.
// Various leak scenarios in error-returns and logs.

import express from 'express';

const app = express();

// 1. Direct stacktrace leak to HTTP response.
app.get('/user/:id', (req, res) => {
    db.get(req.params.id, (err, user) => {
        if (err) { res.send(err.stack); }              // LEAK: full stacktrace
    });
});

// 2. Echo user input back.
app.post('/echo', (req, res) => {
    try {
        safeProcess(req.body);
        res.json({ ok: true });
    } catch (e) {
        res.send(req.body);                             // LEAK: echoes user input
    }
});

// 3. Error message leaks SQL.
app.get('/report', (req, res) => {
    db.query(req.params.q, (err, rows) => {
        if (err) res.status(500).send({ error: err.message });  // LEAK: SQL error text
    });
});

// 4. Safe: throws generic error, no leakage.
app.get('/safe', (req, res) => {
    try { return res.json(doSafe(req)); }
    catch (e) { return res.status(500).json({ error: 'Internal error' }); }
});

// 5. logger.error with stacktrace (log-side leak = forensic attacker reads disk).
logger.error(err.stack);                                // SERVER LOG LEAK

// 6. console.log(request) — dumps entire request including headers.
app.use((req, res, next) => {
    console.log(req);                                    // SERVER LOG LEAK
    next();
});

function safeProcess(_body: any) { /* ok */ }
function db(): any { return null; }
function doSafe(_x: any) { return {}; }
declare var logger: any;
