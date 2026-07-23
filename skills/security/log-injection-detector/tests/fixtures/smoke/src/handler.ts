// Fixture for log-injection-detector.
// Express handler with unsafe and safe log statements across 6 scenarios.

import express, { Request, Response } from 'express';

const app = express();
const logger = console;

// Scenario 1: Safe log — fixed message, no variables.
app.get('/health', (_req: Request, res: Response) => {
    logger.info('Health check passed');
    res.json({ ok: true });
});

// Scenario 2: log with req.body directly — unsafe, user-controlled argument.
app.post('/order', (req: Request, res: Response) => {
    logger.info('Order request: ' + req.body);
    res.json({ received: true });
});

// Scenario 3: log with req.query param — unsafe, attacker-controlled via URL.
app.get('/search', (req: Request, res: Response) => {
    console.log(`Search query: ${req.query.q}`);
    res.json({ results: [] });
});

// Scenario 4: log with sanitized input — safe because escaped/stripped.
app.post('/comment', (req: Request, res: Response) => {
    const safeMsg = (req.body.message || '').replace(/[\r\n]/g, '').substring(0, 200);
    logger.info('Comment: ' + safeMsg);
    res.json({ posted: true });
});

// Scenario 5: log with password variable — sensitive data leak.
app.post('/login', (req: Request, res: Response) => {
    const { username, password } = req.body;
    logger.info('Login attempt: ' + username + ' with password ' + password);
    res.json({ status: 'ok' });
});

// Scenario 6: logger.error with user-controlled message — CRLF injection risk.
app.post('/feedback', (req: Request, res: Response) => {
    try {
        throw new Error('processing failed');
    } catch (err) {
        logger.error('Feedback error from user: ' + req.body.feedback);
        res.status(500).json({ error: 'internal error' });
    }
});
