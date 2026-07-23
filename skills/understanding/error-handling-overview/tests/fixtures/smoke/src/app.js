const express = require('express');
const { AppError } = require('./errors/AppError');

const app = express();

// Global error middleware: logs error and returns generic response
app.use((err, req, res, next) => {
    console.error(err.stack);
    res.status(err.statusCode || 500).json({
        error: 'Internal server error',
        requestId: req.id
    });
});

// Route with try/catch that rethrows wrapped error
app.get('/users/:id', async (req, res, next) => {
    try {
        const user = await db.findUser(req.params.id);
        if (!user) {
            throw new AppError('User not found', 404);
        }
        res.json(user);
    } catch (err) {
        next(err);
    }
});

// Route with try/catch that swallows
app.post('/track', (req, res) => {
    try {
        analytics.track(req.body);
    } catch (e) {
        // Analytics failure is non-critical
    }
    res.json({ ok: true });
});

app.listen(3000);
