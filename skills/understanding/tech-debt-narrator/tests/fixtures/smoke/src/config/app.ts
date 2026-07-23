export interface AppConfig {
  port: number;
  databaseUrl: string;
  redisUrl: string;
}

// FIXME: use env-based config with .env validation
export const config: AppConfig = {
  port: 3000,
  databaseUrl: 'postgresql://localhost:5432/app',
  redisUrl: 'redis://localhost:6379',
};
