// Fixture for wheel-reinvention-detector.
// Mixed: hand-rolled groupBy/chunk (candidates) + 1 genuinely custom function.

import { groupBy, chunk } from 'lodash';

export function handGrouped<T>(items: T[], key: string): Map<string, T[]> {
    const out = new Map<string, T[]>();
    for (const x of items) {
        const k = String((x as any)[key]);
        if (!out.has(k)) out.set(k, []);
        (out.get(k) as T[]).push(x);
    }
    return out;
}

export function handChunked<T>(items: T[], size: number): T[][] {
    const result: T[][] = [];
    for (let i = 0; i < items.length; i += size) {
        result.push(items.slice(i, i + size));
    }
    return result;
}

// Genuinely custom: domain-specific batch loader with retry policy.
export function batchedLoader<T>(url: string, batchSize: number, maxRetries: number) {
    const seen = new Set<string>();
    const pending: string[] = [];
    return { seen, pending, batchSize, maxRetries, url };
}
