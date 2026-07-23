const config = {
  port: parseInt(process.env.PORT ?? '3000', 10),
  dbUrl: process.env.DATABASE_URL ?? 'postgres://localhost:5432/app',
  logLevel: process.env.LOG_LEVEL ?? 'info',
};

export default config;
