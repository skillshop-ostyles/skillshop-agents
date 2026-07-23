// Fixture for data-flow-cartographer.
// Config file reader: reads YAML config file -> parses -> writes to config object.

import fs from 'fs';
import { logger } from '../db/prisma';

interface AppConfig {
  port: number;
  database: { host: string; port: number; name: string };
  stripe: { apiKey: string; webhookSecret: string };
  logging: { level: string; file: string };
}

const config: AppConfig = {
  port: 3000,
  database: { host: 'localhost', port: 5432, name: 'myapp' },
  stripe: { apiKey: '', webhookSecret: '' },
  logging: { level: 'info', file: '/var/log/app.log' }
};

export function loadConfig(configPath: string): AppConfig {
  // Read config from file
  const raw = fs.readFileSync(configPath, 'utf-8');

  // Simple YAML-like parser (for fixture purposes)
  const lines = raw.split('\n');
  for (const line of lines) {
    const trimmed = line.trim();
    if (trimmed.startsWith('#')) continue;
    if (trimmed === '') continue;

    // Parse simple key: value pairs
    const match = trimmed.match(/^(\w[\w.]*):\s*(.+)/);
    if (match) {
      const key = match[1];
      const value = match[2].trim();

      // Write parsed config to memory (sink: config object assignment)
      setNestedConfig(config, key, value);
    }
  }

  logger.info('Configuration loaded', { path: configPath });
  return config;
}

function setNestedConfig(obj: any, key: string, value: string): void {
  const parts = key.split('.');
  let current = obj;
  for (let i = 0; i < parts.length - 1; i++) {
    if (!current[parts[i]]) current[parts[i]] = {};
    current = current[parts[i]];
  }
  // Value conversion for known types
  const lastKey = parts[parts.length - 1];
  if (value === 'true') current[lastKey] = true;
  else if (value === 'false') current[lastKey] = false;
  else if (/^\d+$/.test(value)) current[lastKey] = parseInt(value, 10);
  else current[lastKey] = value;
}
