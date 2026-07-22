const dbUrl = process.env.DATABASE_URL ?? 'postgresql://localhost:5432/fallback';
const apiKey = process.env.API_KEY;
const { NODE_ENV } = process.env;
const missingVar = process.env.NONEXISTENT;
const logLevel = process.env['LOG_LEVEL'];
