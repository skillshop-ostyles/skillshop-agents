const express = require('express');
const app = express();

// --- HTTP Server with graceful shutdown ---
const server = app.listen(3000, () => {
    console.log('Server listening on port 3000');
});

process.on('SIGTERM', () => {
    console.log('SIGTERM received. Draining connections...');
    server.close(() => {
        console.log('All connections closed. Exiting.');
        cleanupResources();
        process.exit(0);
    });
    setTimeout(() => {
        console.error('Grace period expired. Forcing exit.');
        process.exit(1);
    }, 10000).unref();
});

function cleanupResources() {
    console.log('Cleaning up database connections...');
    console.log('Closing file descriptors...');
}

app.get('/health', (req, res) => {
    res.json({ status: 'ok' });
});

// --- Bull worker with no signal handler (abrupt) ---
const Queue = require('bull');
const emailQueue = new Queue('email');

emailQueue.process(async (job) => {
    console.log(`Processing email job ${job.id}`);
    await sendEmail(job.data);
});

function sendEmail(data) {
    return Promise.resolve('sent');
}

// --- Cron job running DB migration with no safe abort (dangerous) ---
const cron = require('node-cron');

cron.schedule('0 3 * * *', async () => {
    console.log('Starting scheduled DB migration...');
    const db = getDatabaseConnection();
    await db.query('ALTER TABLE users ADD COLUMN last_login TIMESTAMP');
    await db.query('UPDATE users SET last_login = NOW()');
    console.log('Migration complete.');
});

function getDatabaseConnection() {
    return { query: async (sql) => console.log(`Executing: ${sql}`) };
}
