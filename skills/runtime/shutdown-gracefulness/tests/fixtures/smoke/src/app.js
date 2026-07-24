const express = require('express');
const app = express();
const server = app.listen(3000);

// SAFE: SIGTERM with drain, grace period, error handling
process.on('SIGTERM', async () => {
  console.log('Shutting down gracefully...');
  server.close(() => {
    console.log('Server closed, no more connections');
  });
  setTimeout(() => {
    process.exit(0);
  }, 10000).unref();
});

// RISKY: Worker with no shutdown handler at all
const Queue = require('bull');
const jobQueue = new Queue('jobs');
jobQueue.process(async (job) => {
  await processJob(job.data);
});
// No process.on('SIGTERM'), no queue.close() — jobs interrupted mid-execution

// DANGEROUS: File writer without flush in shutdown
const fs = require('fs');
const logStream = fs.createWriteStream('./app.log', { flags: 'a' });
process.on('SIGINT', () => {
  process.exit(0); // Immediate exit, no stream.end() — data loss
});

// RISKY: DB pool without drain in shutdown
const { Pool } = require('pg');
const pool = new Pool();
process.on('beforeExit', () => {
  // No pool.end() — in-flight queries dropped
});

app.get('/health', (req, res) => res.json({ status: 'ok' }));
