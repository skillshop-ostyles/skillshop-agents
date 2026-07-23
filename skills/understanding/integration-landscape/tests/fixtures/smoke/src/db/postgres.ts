import { Pool } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL ?? 'postgres://localhost:5432/app',
});

export async function query(text: string, params?: any[]) {
  return pool.query(text, params);
}

export default pool;
