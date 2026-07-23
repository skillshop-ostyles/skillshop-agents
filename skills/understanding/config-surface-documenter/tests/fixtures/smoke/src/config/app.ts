const PORT = parseInt(process.env.PORT ?? '3000', 10);
const DB_URL = process.env.DATABASE_URL ?? 'postgres://localhost:5432/app';
const LOG_LEVEL = process.env.LOG_LEVEL ?? 'info';
const SECRET_KEY = process.env.SECRET_KEY;
const REDIS_URL = process.env.REDIS_URL ?? 'redis://localhost:6379';
