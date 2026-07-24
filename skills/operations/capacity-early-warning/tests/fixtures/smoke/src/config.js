module.exports = {
  db: {
    pool: 10,
    timeout: 30000,
    maxConnections: 50
  },
  server: {
    port: 3000,
    bodyLimit: '5mb',
    rateLimit: 100,
    timeout: 30000
  },
  workers: {
    concurrency: 4,
    batchSize: 100
  },
  cache: {
    ttl: 3600000,
    maxSize: 1000
  }
};
