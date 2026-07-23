import Redis from 'ioredis';

const redis = new Redis(process.env.REDIS_URL ?? 'redis://localhost:6379');

export async function getCached(key: string): Promise<string | null> {
  try {
    return await redis.get(key);
  } catch {
    console.warn('Redis unavailable, using DB fallback');
    return null;
  }
}
